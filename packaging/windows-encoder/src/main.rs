use std::{
    error::Error,
    io::{self, Read},
    path::PathBuf,
};

use windows::{
    core::{GUID, HSTRING},
    Win32::{
        Media::MediaFoundation::*,
        System::Com::{CoInitializeEx, CoUninitialize, COINIT_MULTITHREADED},
    },
};

struct Options {
    width: u32,
    height: u32,
    fps: u32,
    frames: u32,
    path: PathBuf,
}

impl Options {
    fn parse() -> Result<Self, Box<dyn Error>> {
        let mut args = std::env::args_os().skip(1);
        let mut number = || -> Result<u32, Box<dyn Error>> {
            Ok(args
                .next()
                .ok_or("Missing encoder argument.")?
                .into_string()
                .map_err(|_| "Invalid encoder number.")?
                .parse()?)
        };
        let (width, height, fps, frames) = (number()?, number()?, number()?, number()?);
        let path = PathBuf::from(args.next().ok_or("Missing video output path.")?);
        if args.next().is_some()
            || !path.is_absolute()
            || !(2..=8192).contains(&width)
            || !(2..=8192).contains(&height)
            || width % 2 != 0
            || height % 2 != 0
            || width * height > 16_777_216
            || ![24, 25, 30, 50, 60].contains(&fps)
            || !(1..=3600).contains(&frames)
        {
            return Err("Invalid encoder settings.".into());
        }
        Ok(Self {
            width,
            height,
            fps,
            frames,
            path,
        })
    }
}

struct Com;
impl Com {
    fn start() -> windows::core::Result<Self> {
        // This is a standalone process. Initialize and uninitialize COM on the main thread.
        unsafe {
            CoInitializeEx(None, COINIT_MULTITHREADED).ok()?;
        }
        Ok(Self)
    }
}
impl Drop for Com {
    fn drop(&mut self) {
        unsafe { CoUninitialize() };
    }
}

struct MediaFoundation;
impl MediaFoundation {
    fn start() -> windows::core::Result<Self> {
        unsafe {
            MFStartup(MF_VERSION, MFSTARTUP_FULL)?;
        }
        Ok(Self)
    }
}
impl Drop for MediaFoundation {
    fn drop(&mut self) {
        let _ = unsafe { MFShutdown() };
    }
}

fn pair(first: u32, second: u32) -> u64 {
    (u64::from(first) << 32) | u64::from(second)
}

fn media_type(options: &Options, subtype: &GUID) -> windows::core::Result<IMFMediaType> {
    // The caller keeps Media Foundation initialized for the lifetime of the returned COM object.
    unsafe {
        let media = MFCreateMediaType()?;
        media.SetGUID(&MF_MT_MAJOR_TYPE, &MFMediaType_Video)?;
        media.SetGUID(&MF_MT_SUBTYPE, subtype)?;
        media.SetUINT32(&MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive.0 as u32)?;
        media.SetUINT64(&MF_MT_FRAME_SIZE, pair(options.width, options.height))?;
        media.SetUINT64(&MF_MT_FRAME_RATE, pair(options.fps, 1))?;
        media.SetUINT64(&MF_MT_PIXEL_ASPECT_RATIO, pair(1, 1))?;
        media.SetUINT32(&MF_MT_VIDEO_PRIMARIES, MFVideoPrimaries_BT709.0 as u32)?;
        media.SetUINT32(&MF_MT_TRANSFER_FUNCTION, MFVideoTransFunc_709.0 as u32)?;
        media.SetUINT32(&MF_MT_YUV_MATRIX, MFVideoTransferMatrix_BT709.0 as u32)?;
        media.SetUINT32(&MF_MT_VIDEO_NOMINAL_RANGE, MFNominalRange_16_235.0 as u32)?;
        Ok(media)
    }
}

fn to_nv12(rgba: &[u8], nv12: &mut [u8], width: usize, height: usize) {
    let (luma, chroma) = nv12.split_at_mut(width * height);
    for y in (0..height).step_by(2) {
        for x in (0..width).step_by(2) {
            let mut red = 0;
            let mut green = 0;
            let mut blue = 0;
            for offset in [0, 1, width, width + 1] {
                let index = y * width + x + offset;
                let r = i32::from(rgba[index * 4]);
                let g = i32::from(rgba[index * 4 + 1]);
                let b = i32::from(rgba[index * 4 + 2]);
                luma[index] = (16 + ((47 * r + 157 * g + 16 * b + 128) >> 8)).clamp(16, 235) as u8;
                red += r;
                green += g;
                blue += b;
            }
            let index = (y / 2) * width + x;
            chroma[index] =
                (128 + ((-26 * red - 87 * green + 112 * blue + 512) >> 10)).clamp(16, 240) as u8;
            chroma[index + 1] =
                (128 + ((112 * red - 102 * green - 10 * blue + 512) >> 10)).clamp(16, 240) as u8;
        }
    }
}

fn write_frame(
    writer: &IMFSinkWriter,
    stream: u32,
    options: &Options,
    frame: u32,
    rgba: &[u8],
) -> windows::core::Result<()> {
    let pixels = options.width * options.height;
    let bytes = pixels + pixels / 2;
    // The buffer stays locked while its writable bytes are borrowed and is unlocked before submission.
    unsafe {
        let buffer = MFCreateMemoryBuffer(bytes)?;
        let mut data = std::ptr::null_mut();
        let mut capacity = 0;
        buffer.Lock(&mut data, Some(&mut capacity), None)?;
        if data.is_null() || capacity < bytes {
            buffer.Unlock()?;
            return Err(windows::core::Error::from_hresult(windows::core::HRESULT(
                0x8007000Eu32 as i32,
            )));
        }
        to_nv12(
            rgba,
            std::slice::from_raw_parts_mut(data, bytes as usize),
            options.width as usize,
            options.height as usize,
        );
        buffer.Unlock()?;
        buffer.SetCurrentLength(bytes)?;
        let sample = MFCreateSample()?;
        sample.AddBuffer(&buffer)?;
        let timestamp = |index| i64::from(index) * 10_000_000 / i64::from(options.fps);
        sample.SetSampleTime(timestamp(frame))?;
        sample.SetSampleDuration(timestamp(frame + 1) - timestamp(frame))?;
        writer.WriteSample(stream, &sample)
    }
}

fn encode(options: &Options) -> Result<(), Box<dyn Error>> {
    let _com = Com::start()?;
    let _foundation = MediaFoundation::start()?;
    let file = HSTRING::from(options.path.as_os_str());
    // The writer and media types are local to the initialized COM thread.
    let (writer, stream) = unsafe {
        let writer =
            MFCreateSinkWriterFromURL(&file, None::<&IMFByteStream>, None::<&IMFAttributes>)?;
        let output = media_type(options, &MFVideoFormat_H264)?;
        let bitrate = (f64::from(options.width * options.height) * f64::from(options.fps) * 0.18)
            .max(1_500_000.0) as u32;
        output.SetUINT32(&MF_MT_AVG_BITRATE, bitrate)?;
        let stream = writer.AddStream(&output)?;
        let input = media_type(options, &MFVideoFormat_NV12)?;
        input.SetUINT32(&MF_MT_DEFAULT_STRIDE, options.width)?;
        writer.SetInputMediaType(stream, &input, None::<&IMFAttributes>)?;
        writer.BeginWriting()?;
        (writer, stream)
    };
    let mut input = io::stdin().lock();
    let mut rgba = vec![0; (options.width * options.height * 4) as usize];
    for frame in 0..options.frames {
        input.read_exact(&mut rgba)?;
        write_frame(&writer, stream, options, frame, &rgba)?;
    }
    unsafe {
        writer.Finalize()?;
    }
    Ok(())
}

fn main() {
    if let Err(error) = Options::parse().and_then(|options| encode(&options)) {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
