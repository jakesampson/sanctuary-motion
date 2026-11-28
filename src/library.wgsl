// Each look returns midtone illumination and highlight intensity.
// look_t(i) is the live Studio slider in that look's native units.

fn t(i: u32) -> f32 { return look_t(i); }

fn box_distance(p: vec2f, half_size: vec2f, radius: f32) -> f32 {
    let q = abs(p) - half_size + radius;
    return length(max(q, vec2f(0))) + min(max(q.x,q.y),0.0) - radius;
}

fn band(d: f32, width: f32) -> f32 {
    return exp(-abs(d)/max(0.001,width));
}

fn emitter(d: f32, power: f32) -> vec2f {
    return vec2f(band(d,0.064)*0.84,band(d,0.013)*power);
}

fn line_segment(p: vec2f, a: vec2f, b: vec2f) -> f32 {
    let axis = b-a;
    return length(p-a-axis*clamp(dot(p-a,axis)/dot(axis,axis),0.0,1.0));
}

fn rotate2(p: vec2f, deg: f32) -> vec2f {
    let a = radians(deg);
    return vec2f(p.x*cos(a)-p.y*sin(a), p.x*sin(a)+p.y*cos(a));
}

fn radial_rays(v: vec2f, count: f32, fade: f32, sharpness: f32, seed: f32, drift: vec2f) -> vec2f {
    let angle = atan2(v.y,v.x);
    let lobes = max(1.0, count)*2.0;
    let ray = pow(0.5+0.5*cos(angle*lobes+drift.y+seed*0.2), mix(2.4, 16.0, clamp(sharpness,0.0,1.0)));
    let haze = 0.42+0.58*mist(v*5.0+drift+seed);
    let taper = exp(-length(v)*mix(0.35, 3.4, clamp(fade,0.05,1.5)))*haze;
    return vec2f(taper*(0.22+ray), taper*ray*0.92);
}

fn glitter_field(p: vec2f, density: f32, size: f32, twinkle: f32, tphase: f32, seed: f32) -> vec2f {
    let scale = mix(6.0, 42.0, clamp(density/30.0,0.0,1.0));
    let cell = floor(p*scale);
    var light = 0.0;
    for (var y=-1; y<=1; y++) {
        for (var x=-1; x<=1; x++) {
            let home = cell+vec2f(f32(x),f32(y));
            let key = home+seed;
            let offset = vec2f(hash(key), hash(key+4.1));
            let spark = hash(key+9.2);
            let center = (home+offset)/scale;
            let d = length(p-center);
            let radius = mix(0.004, 0.028, size)*(0.45+0.55*spark);
            let pulse = 0.35+0.65*pow(0.5+0.5*sin(tphase*3.0+spark*40.0), mix(1.0, 8.0, twinkle));
            light += exp(-pow(d/max(0.001,radius),2.0)*4.0)*pulse;
        }
    }
    return vec2f(light*0.45, light);
}

fn opening_mask(p: vec2f, size: f32, roundness: f32) -> vec2f {
    let d = box_distance(p, vec2f(size*0.42, size*0.28), mix(0.01, size*0.28, roundness));
    let fill = 1.0-smoothstep(-0.02, 0.01, d);
    return vec2f(fill*0.72+band(d,0.05), fill*0.4+band(d,0.012));
}

fn grid_cells(p: vec2f, cols: f32, rows: f32, gap: f32, seed: f32, phase: f32) -> vec2f {
    let grid = p*vec2f(max(2.0,cols), max(2.0,rows))+0.5;
    let cell = floor(grid);
    let f = fract(grid)-0.5;
    let random = hash(cell+seed);
    let lit = 0.35+0.65*smoothstep(0.15,0.75,0.5+0.5*sin(phase+random*6.2));
    let mask = 1.0-smoothstep(0.42-gap*0.2, 0.49, max(abs(f.x),abs(f.y)));
    return vec2f(mask*lit*0.8, mask*lit*random);
}

// A restrained, loop-safe camera sway. `amount` comes from each look's own
// Camera move / Motion amount / Flow slider; the caller passes it in.
fn camera_shift(drift: vec2f, amount: f32, time: f32) -> vec2f {
    return drift * (0.018 + amount * 0.075)
        + vec2f(sin(time), cos(time)) * amount * 0.024;
}

// Fine animated texture for controls explicitly named Grain / Snow / Static.
fn soft_grain(p: vec2f, strength: f32, time: f32, seed: f32) -> f32 {
    let scale = mix(28.0, 96.0, clamp(strength, 0.0, 1.0));
    let cell = floor(p * scale);
    let frame = fract(floor(time / 6.283185307 * 4.0) / 4.0);
    return strength * (hash(cell + vec2f(frame * 19.0, seed)) - 0.5) * 0.18;
}

// Small ink marks and light points shared by the editorial looks. All control
// values are passed in by the calling case, so each look keeps its own sliders.
fn ink_scene(p: vec2f, ink_x: f32, ink_y: f32, ink_size: f32, ink_layout: f32,
             stop_move: f32, light_x: f32, light_y: f32, time: f32, seed: f32) -> vec2f {
    let steps = round(mix(2.0, 12.0, clamp(stop_move, 0.0, 1.0)));
    let frame = fract(floor(time / 6.283185307 * steps) / steps);
    let jump = vec2f(sin(frame * 6.283185307), cos(frame * 6.283185307)) * 0.018;
    let scale = mix(3.0, 12.0, clamp(ink_layout / 30.0, 0.0, 1.0));
    let g = (p + vec2f(ink_x, ink_y) * 0.1 + jump) * scale;
    let cell = floor(g);
    let f = fract(g) - 0.5;
    let h = hash(cell + seed * 0.31);
    let center = (vec2f(hash(cell + 1.7), hash(cell + 5.3)) - 0.5) * 0.5;
    let radius = mix(0.06, 0.4, clamp(ink_size / 2.5, 0.0, 1.0)) * (0.65 + 0.35 * h);
    let ink = smoothstep(radius, radius * 0.35, length(f - center)) * step(0.42, h);
    let lp = p - vec2f(light_x, light_y) * 0.12 - vec2f(0.08, -0.06);
    let lights = exp(-26.0 * dot(lp, lp));
    return vec2f(ink * 0.55 + lights * 0.16, ink * 0.3 + lights * 0.42);
}

fn library_look(look: u32, uv: vec2f, time: f32, drift: vec2f, seed: f32) -> vec2f {
    let q = uv-0.5;
    let aspect = settings.composition;
    let p = q*vec2f(max(1.0,aspect),max(1.0,1.0/aspect));
    let r = length(p);
    let a = atan2(p.y,p.x);
    switch look {
        case 0u: { // Aurora · Folds / Height / Shimmer
            let folds = t(0u);
            let height = t(1u);
            let shimmer = t(2u);
            let ripple = sin(p.x*folds*1.8+seed*0.3+drift.x)*0.12 + sin(p.x*folds*3.4+drift.y)*0.05;
            let haze = mist(p*4.8+drift*0.65+seed);
            let veil = p.y - height*0.55 + ripple + (haze-0.5)*mix(0.08,0.42,shimmer);
            let body = exp(-11.0*abs(veil))*smoothstep(0.12,0.78,haze)*1.46 + 0.19*haze;
            let glow = exp(-88.0*pow(veil+0.035,2.0))*haze*mix(0.35,1.2,shimmer);
            return vec2f(body, glow);
        }
        case 1u: { // Silk · Waves / Softness / Tilt
            let v = rotate2(p, t(2u));
            let flow = v.y*t(0u)*3.6 + sin(v.x*4.1+drift.x+seed)*2.2 + v.x*3.0;
            let folds = sin(flow+sin(flow*1.9+drift.y)*0.68);
            let soft = mix(0.7, 3.2, t(1u));
            let body = pow(folds*0.5+0.5, soft)*0.78;
            return vec2f(body, pow(folds*0.5+0.5, 8.0)*mix(0.2,0.8,1.0-t(1u)));
        }
        case 2u: { // Bokeh · Lights / Strength / Size
            let lights = drifting_lights(p*(0.55+t(2u)), time, seed, false);
            return vec2f(mist(p*2.2+drift*0.24+seed)*0.28, lights*t(1u)*1.15*(t(0u)/9.0));
        }
        case 3u: { // Dust · Spread / Dust / Sway
            let sway = drift*t(2u);
            let beam = exp(-mix(1.2,8.0,1.0-t(0u))*pow(p.x + p.y*0.9 + sway.x*0.12,2.0));
            let motes = drifting_lights(p,time,seed+12.0,true)*t(1u);
            return vec2f(beam*mist(p*5.0+seed+sway)*0.65, motes*beam*1.2);
        }
        case 4u: { // Fog · Height / Thickness / Backlight
            let fog = mist(p*mix(1.6,4.8,t(1u))+vec2f(0.75,0.38)*drift+seed);
            let wisps = mist(p*6.0+fog+drift*0.47+seed*1.6);
            let bandh = smoothstep(t(0u)-0.35, t(0u)+0.45, p.y);
            let body = smoothstep(0.22,0.82,fog)*0.84*bandh;
            return vec2f(body, smoothstep(0.40,0.82,wisps)*body*t(2u));
        }
        case 5u: { // Light Rays
            return radial_rays(p-vec2f(0.0, t(1u)*0.55), t(0u), t(2u), 0.62, seed, drift);
        }
        case 6u: { // Bar Array
            let rows = max(1.0, round(t(6u)));
            let spacing = mix(8.0, 48.0, t(5u));
            let h = mix(0.08, 0.46, t(8u));
            let pat = round(t(7u));
            let col = p.x*spacing + select(0.0, 12.0*sin(p.y*3.0+time), pat<0.5) + drift.x*t(3u)*8.0;
            let bars = pow(0.5+0.5*cos(col*3.14159), mix(2.0,14.0,t(1u)));
            let rowm = 1.0-smoothstep(h, h+0.08, abs(fract(p.y*rows+0.5)-0.5)*2.0);
            let strobe = select(1.0, step(0.45, fract(time*4.0+hash(floor(p*spacing)))), pat>1.5);
            let haze = mist(p*3.0+seed)*t(2u);
            let body = (bars*rowm*strobe*mix(0.4,1.5,t(0u))+haze);
            return vec2f(body, body*t(1u)+t(4u)*hash(floor(p*90.0)+seed)*0.35);
        }
        case 7u: { // Laser Planes
            let n = max(1.0, round(t(5u)));
            let origin = vec2f(0.0, mix(-0.55, 0.2, t(8u)));
            let v = p-origin-camera_shift(drift, t(3u), time);
            let ray = pow(0.5+0.5*cos(atan2(v.y,v.x)*n*2.0+drift.y*t(6u)+seed), mix(3.0,18.0,1.0-t(7u)));
            let taper = exp(-length(v)*1.6)*(0.4+t(1u)*mist(v*5.0));
            return vec2f(taper*(0.2+ray)*t(0u), taper*ray*t(2u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 8u: { // Planet Rise — every Studio control drives the image
            let size = mix(0.18, 0.48, t(5u));
            let detail = t(1u);
            let camera = t(3u);
            let grain = t(4u);
            // Camera move: seamless drift over the loop.
            let shift = vec2f(
                drift.x * mix(0.0, 0.09, camera),
                drift.y * mix(0.0, 0.11, camera) + 0.035 * sin(time) * camera
            );
            let v = vec2f(p.x, p.y - mix(-0.15, 0.45, t(8u))) - shift;
            let d = length(v) - size;
            let rim = emitter(d, t(2u));
            // Surface detail: bands on the disc that travel with the camera.
            let surface = (1.0 - smoothstep(-0.01, 0.01, d))
                * pow(0.5 + 0.5 * sin(v.y * mix(14.0, 54.0, detail) + 1.7 * sin(time + v.x * 3.0)), 3.0)
                * detail * 0.55;
            let atmo = band(d - mix(0.02, 0.12, t(6u)), 0.08) * t(6u);
            let rings = band(abs(v.y) - size * 0.15, mix(0.01, 0.05, t(7u))) * t(7u) * step(abs(v.x), size * 1.4);
            // Grain: fine animated texture across the planet and atmosphere.
            let speckle = grain * hash(floor(v * mix(24.0, 90.0, grain)) + floor(fract(time / 6.283185307) * 3.0) + seed) * 0.12;
            return (rim + vec2f(atmo, atmo) + vec2f(rings * 0.4, rings) + vec2f(surface * 0.55, surface))
                * mix(0.45, 1.4, t(0u)) + vec2f(speckle);
        }
        case 9u: { // Light Corridor — Travel sets the number of frames per loop
            var light = vec2f(0);
            let frames = clamp(round(t(8u)), 2.0, 8.0);
            let shift = camera_shift(drift, t(3u), time);
            let travel = fract(time / 6.283185307 * frames);
            for (var i=0u; i<8u; i++) {
                let index = f32(i);
                if index >= frames { break; }
                let size = 0.33*pow(0.75,index)*(0.8+t(6u)*0.5);
                let v = p - shift + vec2f(0, 0.06*index/max(1.0,frames-1.0) + 0.035*(travel-0.5));
                let d = box_distance(v,vec2f(size*mix(0.8,1.6,t(7u)),size), mix(0.0,0.04,t(5u)));
                light = max(light,emitter(d,0.91-index*0.065)*(0.95-index*0.075));
            }
            let haze = vec2f(mist(p*2.0+drift*0.3+seed), mist(p*2.4+seed)*1.2)*t(1u)*0.16;
            return (light*mix(0.5,1.4,t(0u))+haze+vec2f(soft_grain(p,t(4u),time,seed)))
                + vec2f(0.0, t(2u)*band(p.y+0.45,0.08));
        }
        case 10u: { // Glass Stack
            var output = vec2f(0);
            let panels = clamp(round(t(0u)), 3.0, 16.0);
            for (var n=0u; n<16u; n++) {
                if f32(n) >= panels { break; }
                let i=f32(n)-(panels-1.0)*0.5;
                var v=p-vec2f(i*mix(0.03,0.11,t(3u)),0.03*sin(i+drift.y*t(4u)));
                let size=vec2f(0.045, mix(0.12,0.42,t(1u))-abs(i)*0.012);
                let d=box_distance(v,size,mix(0.004,0.05,t(2u)));
                let facet = 0.36+0.64*pow(cos(i*0.7+drift.x+v.y*7.0),2.0);
                output=max(output,vec2f(1.0-smoothstep(-0.02,0.014,d),band(d,0.022))*facet);
            }
            return output;
        }
        case 11u: { // Long Exposure — Forms layers several streak shapes
            let v = rotate2(p, t(1u));
            let streaks = t(0u);
            let forms = clamp(round(t(3u)), 1.0, 4.0);
            var output = vec2f(0);
            for (var n=0u; n<4u; n++) {
                let i = f32(n);
                if i >= forms { break; }
                let d = v.x + 0.14*sin(v.y*streaks+drift.y*t(4u)+i*1.7) + i*0.045;
                output = max(output, emitter(d, mix(0.2,0.9,t(2u)))
                    * vec2f(1.0, mix(0.4,1.2,t(2u))) * (1.0-i*0.12));
            }
            return output;
        }
        case 12u: { // Glass Fins
            var output = vec2f(0);
            let fins = clamp(round(t(5u)), 3.0, 13.0);
            let shift = camera_shift(drift, t(3u), time);
            for (var n=0u; n<13u; n++) {
                if f32(n) >= fins { break; }
                let i=f32(n)-(fins-1.0)*0.5;
                var v=p-shift-vec2f(i*mix(0.04,0.12,t(8u)),0);
                v.x += v.y*0.16;
                let size=vec2f(mix(0.008,0.04,t(6u)), mix(0.12,0.36,t(7u)));
                let d=box_distance(v,size,0.008);
                output=max(output,vec2f(1.0-smoothstep(-0.02,0.014,d),band(d,0.02))*mix(0.4,1.3,t(0u)));
            }
            return output+vec2f(t(2u)*0.12, t(1u)*0.2)+vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 13u: { // Glass Torus — every Studio control shapes the glass
            let exposure = t(0u);
            let dispersion = t(1u);
            let tint = t(2u);
            let shift = camera_shift(drift, t(3u), time);
            let v = p-shift;
            let flat = mix(1.0, 0.42, t(8u));
            let vp = vec2f(v.x, v.y/flat);
            let rv = length(vp);
            let av = atan2(vp.y, vp.x);
            let radius = mix(0.16, 0.42, t(5u));
            let thick = mix(0.012, 0.10, t(6u));
            let twist = av*max(1.0, round(t(7u)))*3.14159265;
            let wave = thick*0.45*sin(twist+drift.y);
            let rim = rv-radius-wave;
            let facet = 0.2+0.8*pow(0.5+0.5*cos(twist+drift.x), mix(1.0,7.0,1.0-tint));
            let split = band(rim+dispersion*0.012, thick*1.7)-band(rim-dispersion*0.012, thick*1.7);
            let core = band(rim, thick*0.35);
            let warmth = 0.8+tint*0.4;
            return (vec2f(band(rim,thick*1.8)+split*0.35,
                          core*mix(0.5,1.4,1.0-dispersion)+split*0.2)
                    * facet * vec2f(1.0/warmth, warmth) * mix(0.45,1.4,exposure))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 14u: { // Hanging Blades
            var output = vec2f(0);
            let blades = clamp(round(t(0u)), 3.0, 14.0);
            for (var n=0u; n<14u; n++) {
                if f32(n) >= blades { break; }
                let i=f32(n)-(blades-1.0)*0.5;
                let chase = sin(time*round(max(1.0,t(3u)))+i)*t(1u)*0.08;
                let v = p.yx-vec2f(i*0.065,i*0.028+chase);
                let size=vec2f(0.015, mix(0.12,0.38,t(4u))-abs(i)*0.02);
                let d=box_distance(v,size,0.009);
                let stripe = 0.5+0.5*cos(v.y*18.0)*t(2u);
                output=max(output,emitter(d,0.8)*stripe);
            }
            return output;
        }
        case 15u: { // Light Slab
            let d=box_distance(p-vec2f(0, mix(-0.1,0.2,t(3u)+1.0)), vec2f(mix(0.04,0.22,t(0u)), mix(0.12,0.42,t(1u))), 0.007);
            let fill=1.0-smoothstep(-0.015,0.008,d);
            return (emitter(d,t(2u))+vec2f(fill*0.82,fill*t(4u)*0.5));
        }
        case 16u: { // Floating Ellipse
            let v = (p+vec2f(0, -t(2u)*0.35))*vec2f(1.0/mix(0.2,1.4,t(0u)), 1.0/mix(0.05,1.0,t(1u)));
            let d=(length(v)-0.31)/2.0;
            let fill=1.0-smoothstep(-0.02,0.01,d);
            let floor_glow = band(p.y+mix(0.42,0.12,t(4u)), 0.035)*t(4u)*0.3;
            return vec2f(fill*0.7+band(d,0.04)+floor_glow, fill*t(3u)+band(d,0.01)+floor_glow*0.6);
        }
        case 17u: { // Bottom Glow
            let h = mix(0.04, 0.55, t(0u));
            let soft = mix(0.04, 0.22, t(1u));
            let breathe = 0.85+0.15*sin(time*2.0)*t(2u);
            let sway = t(3u)*0.055*sin(time)+drift.x*t(3u)*0.03;
            let glow = band(1.0-uv.y-0.05-sway*p.x*2.0, h)*breathe;
            let edge = band(abs(q.x)-0.42, 0.03)*t(4u)*0.05;
            return vec2f(glow+edge, band(1.0-uv.y, soft)*breathe+edge);
        }
        case 18u: { // Linear Drift
            let dir = rotate2(q, t(0u));
            let ramp=smoothstep(-t(1u), t(1u), dir.x+0.24*drift.x*t(2u)+t(3u)*0.22);
            let contrast = mix(0.6, 1.6, t(4u));
            return vec2f(pow(ramp,contrast)*0.82, pow(ramp,contrast+0.6)*0.60);
        }
        case 19u: { // Edge Light
            let thick = mix(0.02, 0.13, t(0u));
            let d=min(0.5-abs(q.x),0.5-abs(q.y));
            let pulse = 0.7+t(2u)*0.4*(0.75+0.25*sin(time));
            let fog = mist(p*3.0+drift*0.2+seed)*t(3u)*0.22;
            return vec2f(band(d, thick)+fog, band(d, mix(0.01,0.05,1.0-t(1u)))+fog*0.6)*pulse;
        }
        case 20u: { // Mesh
            let n = max(3.0, t(0u));
            var mesh = 0.0;
            for (var i=0u; i<8u; i++) {
                if f32(i) >= n { break; }
                let k = f32(i);
                let c = vec2f(cos(k*2.4+seed), sin(k*1.7+seed*1.3))*0.35;
                mesh += exp(-mix(2.0, 9.0, 1.0-t(1u))*length(p-c-drift*0.08));
            }
            return vec2f(mesh, mesh*mesh*0.81);
        }
        case 21u: { // Bloom Bars
            let bars = max(2.0, t(0u));
            let slat = pow(0.5+0.5*cos(p.x*bars*1.8+time*round(t(2u)*4.0)), mix(2.0,10.0,1.0-t(1u)));
            return vec2f(slat*0.76, slat*0.9)*band(p.y,0.42);
        }
        case 22u: { // Halo
            let radius = t(0u)*0.38;
            let bands = max(2.0, t(1u));
            let v = rotate2(p, t(2u));
            let slat = band(fract((v.y+v.x*0.25)*bands)-0.5, t(3u)*0.18);
            return vec2f(slat*0.76,slat*0.9)*(1.0-smoothstep(radius-0.05,radius+0.08,r));
        }
        case 23u: { // Halo Ring
            let radius = t(0u)*0.42;
            let thick = t(1u);
            let d = r-radius;
            return vec2f(band(d, thick*1.4)+t(2u)*band(d+thick, 0.12), band(d, thick*0.35));
        }
        case 24u: { // Eclipse
            let radius = t(0u)*0.42;
            let d = r-radius;
            let corona = t(1u)*band(d, 0.12)*step(0.0,d);
            let diamond = t(2u)*pow(0.5+0.5*cos(a*4.0), 6.0)*exp(-3.0*r);
            return vec2f(band(d,0.10)*step(0.0,d)+corona, band(d,0.008)+diamond);
        }
        case 25u: { // Cross of Rays
            let v=p+vec2f(0,0.025);
            let d=min(box_distance(v,vec2f(mix(0.01,0.05,t(1u)), mix(0.18,0.42,t(0u))),0.006),
                      box_distance(v+vec2f(0, mix(-0.05,0.16,t(2u))),vec2f(mix(0.12,0.28,t(0u)),0.021),0.005));
            let spokes=pow(0.5+0.5*cos(a*mix(8.0,28.0,t(3u))+drift.x),7.0)*exp(-6.0*r)*t(3u);
            return emitter(d,t(2u))+vec2f(spokes*0.67, (1.0-smoothstep(-0.008,0.005,d))*0.64)
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 26u: { // Silhouette Cross
            let size_scale = mix(0.7, 1.35, t(0u));
            let thick = mix(0.012, 0.05, t(1u));
            let v = p/size_scale+vec2f(0,0.025);
            let d=min(box_distance(v,vec2f(thick,0.32),0.006), box_distance(v+vec2f(0,0.087),vec2f(0.18,thick),0.005));
            let solid=1.0-smoothstep(-0.008,0.005,d);
            let spokes=pow(0.5+0.5*cos(a*21.0+drift.x),7.0)*exp(-6.0*r)*t(3u);
            return (emitter(d,t(2u))+vec2f(spokes,spokes*0.34))*(1.0-solid*0.85)
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 27u: { // Glass Cross
            let shift = camera_shift(drift, t(3u), time);
            let sway = t(8u)*0.03*sin(time*2.0);
            let v=p-shift+vec2f(sway,0.025);
            let size = mix(0.8, 1.3, t(5u));
            let d=min(box_distance(v,vec2f(mix(0.016,0.05,t(6u)), mix(0.2,0.38,t(5u)))/size, mix(0.0,0.02,t(10u))),
                      box_distance(v+vec2f(0,0.08),vec2f(mix(0.12,0.24,t(5u)), mix(0.014,0.04,t(6u)))/size,0.005));
            let facet = 0.5+0.5*sin(p.y*18.0+drift.y);
            let depth = 1.0+t(7u)*0.5*sin(p.x*9.0+time);
            let material = 0.7+0.3*sin(t(9u)*1.7+p.x*3.0);
            let backlight = mist(p*mix(2.0,5.0,t(2u))+drift*0.2+seed)*t(1u)*0.22;
            let dispersion = band(d, mix(0.01,0.05,t(2u)))*t(2u)*0.12;
            return emitter(d,t(0u))*vec2f(0.7*depth, (0.5+0.5*facet)*material)
                + vec2f(backlight+dispersion, backlight*0.8+dispersion)
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 28u: { // Curtain Streaks · Cross
            let curtain=pow(0.5+0.5*cos(p.x*mix(40.0,160.0,t(0u))), mix(4.0,14.0,t(1u)))*band(p.y,0.33);
            let v=(p+vec2f(0,0.025))/mix(0.7,1.5,t(3u));
            let cross_d=min(box_distance(v,vec2f(0.024,0.32),0.006), box_distance(v+vec2f(0,0.087),vec2f(0.18,0.021),0.005));
            let ring_d=abs(length(v)-0.28);
            let diamond_d=abs(v.x)+abs(v.y)-0.31;
            let bars_d=max(abs(fract(v.x*4.0)-0.5)*0.18, abs(v.y)-0.27);
            var shape_d = cross_d;
            let shape = round(t(2u));
            if shape < 0.5 { shape_d = cross_d; }
            else if shape < 1.5 { shape_d = ring_d; }
            else if shape < 2.5 { shape_d = diamond_d; }
            else { shape_d = bars_d; }
            let breath = 1.0+t(5u)*0.3*sin(time*(1.0+round(t(6u))));
            let soft = mix(0.006, 0.05, t(7u));
            let mark = vec2f(band(shape_d,soft)*0.7, band(shape_d,soft*0.3))*t(4u)*breath;
            return (vec2f(curtain*0.58,curtain*0.32)+mark)*mix(0.5,1.5,t(8u));
        }
        case 29u: { // Light Threads — Light play sets the thread width, Exposure sets level
            let width = mix(0.08, 0.3, t(1u));
            let threads = band(p.y+0.11*sin(p.x*6.0+drift.x), width)*0.2;
            return vec2f(threads*t(2u), drifting_lights(p, time, seed, true)*t(0u)*t(2u));
        }
        case 30u: { // Snow Glint
            let fine=drifting_lights(p, time+0.4,seed,true)*t(0u);
            let warmth = mix(0.7, 1.3, t(2u));
            return vec2f(band(q.y-0.45,0.13)*t(1u)*warmth,
                fine+drifting_lights(p+drift*0.04,time,seed+3.0,true)*t(3u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 31u: { // Embers & Snow
            let embers=drifting_lights(p*0.9, time*round(mix(1.0,4.0,t(3u))), seed, false)*t(0u);
            let snow=drifting_lights(p+vec2f(0,0.12*sin(time)), time, seed+8.0, true)*t(1u);
            return vec2f(embers*0.45+snow*0.2, embers+snow*0.6)* (0.6+t(2u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 32u: { // Amber Bokeh
            let bokeh=drifting_lights(p*mix(0.5,1.2,t(3u)),time,seed,false)*t(0u);
            return vec2f(bokeh*0.45, bokeh*(0.6+t(2u))+drifting_lights(p*2.0,time,seed+2.0,true)*t(1u))
                * mix(0.5,1.4,t(4u));
        }
        case 33u: { // Breathing Stars
            let cells=(p+vec2f(t(6u)*0.06*sin(time), t(6u)*0.04*cos(time)))*mix(8.0, 22.0, t(5u));
            let center = fract(cells)-0.5;
            let key = hash(floor(cells)+seed);
            let twinkle=pow(0.5+0.5*sin(key*6.2831853+time*round(mix(1.0,3.0,t(4u)))),3.0);
            let star=band(center.x, mix(0.02,0.08,t(8u)))*band(center.y,0.18)+band(center.y,0.03)*band(center.x,0.18);
            let amount = star*twinkle*t(1u)*step(1.0-t(7u), key);
            let halo = band(length(center),0.2)*t(2u)*twinkle*step(1.0-t(7u), key);
            return vec2f(drifting_lights(p,time,seed,true)*t(0u)*0.2+halo*0.3, amount+halo)
                * mix(0.5,1.5,t(3u));
        }
        case 34u: { // Dot Curtain
            let dots = max(12.0, t(0u));
            let grid=p*vec2f(dots, mix(8.0, 40.0, t(1u)));
            let f=fract(grid)-0.5;
            let mask=1.0-smoothstep(mix(0.08,0.32,t(2u)), 0.45, length(f));
            let fold = 0.6+0.4*sin(p.y*t(3u)+time)*t(4u);
            return vec2f(mask*fold, mask*fold);
        }
        case 35u: { // Burst Fans
            let origin = vec2f(t(1u)*0.45, 0.42);
            return radial_rays(p-origin, t(0u)*0.12, 1.0-t(2u), t(3u), seed, drift)*vec2f(1.0, 0.7+t(4u));
        }
        case 36u: { // Wave Slats
            let slats = max(4.0, t(0u));
            let waves = t(1u);
            let g = pow(0.5+0.5*cos(p.y*slats + sin(p.x*waves+drift.y)*t(4u)*4.0), mix(2.0, 10.0, t(2u)));
            let v = rotate2(p, t(3u)*18.0);
            return vec2f(g,g*0.72)*band(v.x, 0.55);
        }
        case 37u: { // Arch Rows
            let rows = max(4.0, t(0u));
            let v=vec2f(p.x,min(p.y-0.12,0.0));
            let radius=length(v);
            let line=band(fract(radius*rows+drift.x*t(3u)*0.2)-0.5, mix(0.04,0.16,t(1u)));
            let segments=smoothstep(0.27,0.51,noise(vec2f(atan2(v.y,v.x)*20.0,floor(radius*rows))+seed));
            return vec2f(line,line*segments)*smoothstep(0.12, mix(0.18,0.4,t(2u)),radius)*t(4u);
        }
        case 38u: { // Block Wall
            let cols = max(4.0, t(0u));
            let rows = max(3.0, t(1u));
            return grid_cells(p, cols, rows, t(4u), seed, time*round(mix(1.0,3.0,t(2u))))*vec2f(t(3u)+0.4, 1.0);
        }
        case 39u: { // Panel Mosaic
            return grid_cells(p, t(0u), mix(4.0,18.0,t(3u)), t(1u), seed, time)*vec2f(0.7+t(4u), 0.5+t(2u));
        }
        case 40u: { // Silk Light
            let ribbons = clamp(round(t(5u)), 1.0, 3.0);
            var light = emitter(p.y-0.17*sin(p.x*3.0)+0.12, 0.54);
            let width = mix(0.01, 0.07, t(10u))*mix(0.7,1.4,t(2u));
            for (var n=0u; n<3u; n++) {
                let i = f32(n);
                if i >= ribbons { break; }
                let off = (i-(ribbons-1.0)*0.5)*mix(0.08,0.3,t(8u));
                let d = p.y-off+0.14*sin(p.x*mix(1.0,6.0,t(7u))+time*round(t(3u)*2.0)+drift.y)*t(6u);
                light = max(light, vec2f(band(d,width), band(d,0.012)*t(1u)));
            }
            let tint = mix(0.7, 1.3, t(9u));
            return light*vec2f(1.0/tint, tint)*mix(0.5,1.4,t(0u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 41u: { // Caustic Depths
            let haze=mist(p*mix(2.0,6.0,t(1u))+drift*mix(0.2,1.2,t(3u))+seed);
            let caustic=pow(0.5+0.5*sin(p.x*22.0+4.0*haze+drift.x+p.y*1.2), mix(3.0, 11.0, t(2u)));
            return vec2f(caustic*haze,caustic*haze*haze)*mix(0.4,1.4,t(0u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 42u: { // Deep Field
            let flow = camera_shift(drift, t(3u), time);
            let haze=mist(p*mix(2.0,7.0,t(1u))+flow*0.6+seed);
            return vec2f(haze*mix(0.4,1.2,t(0u)), smoothstep(0.45,0.72,haze)*t(2u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 43u: { // Volume Rays
            return radial_rays(p-vec2f(-0.22,-0.48), mix(4.0, 22.0, t(2u)), mix(0.3,1.0,t(1u)), 0.35, seed, drift*t(3u))*mix(0.4,1.5,t(0u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 44u: { // Ramp Squares
            var light = vec2f(0);
            for (var i=0u; i<7u; i++) {
                let index = f32(i);
                let size = mix(0.12,0.4,t(5u))*pow(0.75,index);
                let spin = t(7u)*index*0.35*sin(time+index);
                let v = rotate2(p, spin)+vec2f(sin(index+time*round(t(3u)*2.0)+drift.y)*size*0.22,0);
                let d = box_distance(v,vec2f(size), mix(0.0,0.08,t(6u)));
                light = max(light,emitter(d,0.9-index*0.08)+vec2f(band(d,0.006)*t(2u)*0.5));
            }
            let tint = mix(0.6, 1.5, fract(t(8u)/7.0));
            return light*vec2f(1.0/tint, tint)*mix(0.5,1.5,t(0u))*mix(0.6,1.4,t(1u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 45u: { // Glass Ripple
            let wave = 0.034*sin(a*mix(2.0,12.0,t(5u))+drift.y+time*round(t(3u)*2.0))+0.012*cos(a*9.0);
            let optical = pow(0.5+0.5*cos(mix(20.0, 80.0, t(6u))*(r+wave)+drift.x),4.0);
            let falloff=1.0-smoothstep(mix(0.2,0.32,t(1u)), mix(0.34,0.5,t(1u)), r);
            let rings = band(r-0.2*floor(mix(0.0,1.0,t(7u))*5.0)/5.0, 0.02)*t(7u)*0.2;
            let tint = mix(0.7, 1.4, fract(t(8u)/7.0));
            return vec2f(optical*falloff+rings, optical*falloff*(0.49+t(2u))+rings*0.6)
                *vec2f(1.0/tint,tint)*mix(0.5,1.4,t(0u))+vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 46u: { // Rings
            let waves = pow(0.5+0.5*cos(r*t(0u)*2.5+drift.x), t(2u))*exp(-t(1u)*r);
            return vec2f(waves,waves*0.52);
        }
        case 47u: { // Arc
            let v = vec2f(p.x,p.y-t(2u)*0.35);
            let d = length(v)-t(0u)*0.28;
            return emitter(d, 0.8)*vec2f(1.0, band(d, t(1u))*2.0);
        }
        case 48u: { // Point Wave
            let dens = t(0u);
            return emitter(p.y+0.11*sin(p.x*t(2u)+drift.x)*t(1u),0.7)*vec2f(0.71,0.5+0.5*pow(cos(p.x*dens),4.0))*t(3u);
        }
        case 49u: { // Dot Globe
            let radius = t(0u)*0.4;
            let dots = pow(0.5+0.5*cos(a*t(1u)+drift.x),6.0);
            let d = r-radius;
            let tilt = rotate2(p, t(3u))*vec2f(1.0, 1.0+0.55*sin(radians(t(3u))));
            return vec2f(band(d,0.044)*0.35,band(d, mix(0.008,0.03,t(2u)))*dots*0.75)*step(length(tilt)-0.02, radius+0.08);
        }
        case 50u: { // Phase Rings
            let rings = pow(0.5+0.5*cos(r*t(0u)*12.0+0.8*sin(3.0*a)+drift.y*t(1u)), mix(4.0, 14.0, 1.0-t(2u)));
            return vec2f(rings*0.7,rings*0.83)*exp(-1.5*r);
        }
        case 51u: { // Wire Sphere
            let s = t(0u);
            let v=rotate2(p, t(2u))/max(0.2,s*0.5);
            let z=sqrt(max(0.0,1.0-dot(v,v)));
            let longitude=atan2(v.x,z);
            let latitude=asin(clamp(v.y,-1.0,1.0));
            let line=max(band(fract((longitude+drift.x*0.34)*t(1u)*0.25)-0.5,0.09),band(fract(latitude*t(1u)*0.25)-0.5,0.085));
            let mask=(1.0-smoothstep(0.96,1.0,length(v)))*0.82;
            return vec2f(line,line)*mask*0.8;
        }
        case 52u: { // Wire Cube
            var distance=10.0;
            let angle=t(2u)*0.02+0.43*drift.x;
            let s = t(0u)*0.22;
            for (var n=0u; n<8u; n++) {
                let v=vec3f(select(-1.0,1.0,(n&1u)!=0u),select(-1.0,1.0,(n&2u)!=0u),select(-1.0,1.0,(n&4u)!=0u));
                for (var axis=0u; axis<3u; axis++) {
                    if (n&(1u<<axis))!=0u { continue; }
                    var next=v;
                    next[axis]=1.0;
                    let x=vec2f(cos(angle),sin(angle));
                    let z=vec2f(-x.y,x.x);
                    let u=vec2f(dot(x,v.xz),v.y+0.47*dot(z,v.xz))*s;
                    let w=vec2f(dot(x,next.xz),next.y+0.47*dot(z,next.xz))*s;
                    distance=min(distance,line_segment(p,u,w));
                }
            }
            return emitter(distance, 0.5+t(1u));
        }
        case 53u: { // Halo Bands
            var hoops=vec2f(0);
            let nmax = max(1.0, t(0u));
            for (var n=0u; n<6u; n++) {
                if f32(n) >= nmax { break; }
                let y=(f32(n)-nmax*0.5)*t(1u);
                let d=(length(vec2f(p.x,(p.y-y)*4.0))-0.30)*0.38;
                hoops=max(hoops,emitter(d,0.51+t(2u))*(0.65+0.30*cos(f32(n)+time)));
            }
            return hoops;
        }
        case 54u: { // Nested Squares
            var light = vec2f(0);
            let nmax = max(2.0, t(0u));
            for (var i=0u; i<12u; i++) {
                if f32(i) >= nmax { break; }
                let size = 0.42*pow(0.72, f32(i));
                let d = box_distance(p, vec2f(size), 0.0);
                light = max(light, vec2f(band(d, mix(0.008,0.04,t(1u))), band(d,0.006)*t(2u)));
            }
            return light;
        }
        case 55u: { // Moiré
            let lines = t(0u);
            let off = t(1u);
            let a1 = 0.5+0.5*cos(p.x*lines + p.y*off);
            let a2 = 0.5+0.5*cos(p.y*lines + p.x*off*0.7);
            let m = a1*a2;
            return vec2f(m, m*m)*mix(0.6, 1.4, 1.0-t(2u));
        }
        case 56u: { // Checker Warp
            let g = t(0u);
            let warped = p + vec2f(0.45*sin(p.y*10.0+drift.x), 0.4*sin(p.x*6.0))*t(1u);
            let cell = floor(warped*g);
            let v = abs(fract((cell.x+cell.y)*0.5)*2.0-1.0);
            return vec2f(v, v*v)*mix(0.5,1.2,1.0-t(2u));
        }
        case 57u: { // Grid Floor
            let depth = max(0.008, q.y - t(1u));
            let perspective=vec2f(q.x/depth, 0.28/depth);
            let dens = t(0u);
            let lines=max(band(fract(perspective.x*dens*0.35)-0.5,0.055),band(fract(perspective.y+drift.y*0.24)-0.5,0.044));
            let ground=lines*smoothstep(0.018,0.40,depth);
            return vec2f(ground*0.85+band(q.y,0.04)*t(2u),ground*0.67);
        }
        case 58u: { // Dune Lines
            let lines = t(0u);
            return emitter(fract(p.y*lines + sin(p.x*3.0)*t(1u)+drift.y*0.16)-0.5, 0.69)*vec2f(0.61, 0.4+t(2u));
        }
        case 59u: { // Scan Grid
            let g = t(0u);
            let grid=p*vec2f(g, g*0.7);
            let f=fract(grid)-0.5;
            let mask=max(band(abs(f.x)-0.5, mix(0.01,0.06,t(1u))), band(abs(f.y)-0.5,0.02));
            return vec2f(mask, mask*t(2u))*band(q.y-0.1, 0.4);
        }
        case 60u: { // Circuit
            let dens = t(0u);
            let grid=p*dens;
            let f=fract(grid)-0.5;
            let random=hash(floor(grid)+seed);
            let trace=select(band(f.x,0.038),band(f.y,0.038),random>0.5);
            let pulse = 0.5+0.5*sin(time*round(mix(1.0,9.0,t(1u)))+random*20.0)*t(2u);
            return vec2f(trace*step(0.48,random), trace*pulse);
        }
        case 61u: { // Ripple Floor
            let depth = max(0.008,q.y-t(2u));
            let ripple=band(fract(length(p-vec2f(0,0.53))*t(0u)*1.8+0.18*drift.x)-0.5,0.064);
            let ground=ripple*smoothstep(0.018,0.40,depth);
            return vec2f(ground*0.85, ground*t(1u));
        }
        case 62u: { // Chalk Smear
            let steps = round(mix(2.0, 10.0, t(4u)));
            let frame = fract(floor(time / 6.283185307 * steps) / steps);
            let jump = vec2f(frame*0.05, -frame*0.03);
            let v=vec2f(p.x+p.y*0.8,p.y)+jump;
            let stroke=mist(v*vec2f(mix(12.0, 60.0, t(3u)/16.0),5.0)+drift*t(2u)+seed);
            let mark=smoothstep(0.36,0.72,stroke*mist(p*3.0)*1.55)*t(0u);
            return vec2f(mark*0.58, mark*t(1u)+t(5u)*hash(floor(p*80.0)+frame*11.0));
        }
        case 63u: { // Failing Ceiling
            let ceiling_layout = round(t(6u));
            let cols = mix(4.0,16.0,t(5u))*(1.0+0.12*ceiling_layout);
            let rows = mix(3.0,12.0,t(5u))*(1.0-0.08*ceiling_layout);
            let shift = camera_shift(drift, t(7u), time);
            let speed = round(mix(1.0, 5.0, t(3u)))*round(mix(1.0, 3.0, t(10u)));
            let cells = grid_cells(p-shift, cols, rows, 0.12, seed, time*speed);
            let behind = mist(p*mix(2.0,6.0,t(9u)/3.0)+drift*0.2+seed)*t(9u)*0.12;
            let dim = 0.5+t(8u)*hash(floor(p*9.0)+floor(fract(time / 6.283185307)*2.0));
            return (cells*vec2f(t(0u), t(2u))+vec2f(behind))*mix(0.6,1.4,t(1u))*dim
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 64u: { // Office Ceiling — sliders now drive the ceiling grid and its motion
            let ceiling_layout = round(t(6u));
            let size = mix(6.0, 20.0, t(5u));
            let cols = size*(1.0+0.1*ceiling_layout);
            let rows = size*0.68*(1.0-0.08*ceiling_layout);
            let shift = camera_shift(drift, t(7u), time);
            let speed = round(mix(1.0, 5.0, t(3u)))*round(mix(1.0, 3.0, t(10u)));
            let cells = grid_cells(p-shift, cols, rows, 0.08, seed, time*speed);
            let behind = band(p.y+0.24, 0.14)*t(9u)*0.16;
            let dim = mix(1.0, 0.45, t(8u));
            return (cells*vec2f(t(0u)+0.3, t(1u)+0.3+t(2u)*0.4)+vec2f(behind))*dim
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 65u: { // Rays
            return radial_rays(p-vec2f(0.0, t(1u)*0.5), t(0u), t(2u), 0.55, seed, drift);
        }
        case 66u: { // Scan Beam
            let v = rotate2(p, t(2u));
            let core = band(v.x, t(0u));
            let trail = smoothstep(0.0, 1.0, 0.5-v.y)*t(1u)*core;
            return vec2f(core*0.7+trail, core+trail);
        }
        case 67u: { // Streaks
            let v = rotate2(p, t(2u));
            let n = t(0u);
            let lines = pow(0.5+0.5*cos(v.x*n), mix(4.0, 18.0, 1.0-t(1u)));
            return vec2f(lines*0.55, lines)*smoothstep(-0.2, 0.5, 0.4-abs(v.y));
        }
        case 68u: { // Hidden Light
            let shift = camera_shift(drift, t(1u), time);
            let roundness = clamp(t(4u)+t(5u)*0.25*sin(time), 0.0, 1.0);
            let spill = vec2f(t(2u)*band(p.y+0.42+0.08*sin(time)*t(3u), 0.1), t(2u)*0.4);
            return opening_mask(p-shift, t(0u), roundness)*vec2f(0.8, t(2u))+spill;
        }
        case 69u: { // Sky Opening
            return opening_mask(p-vec2f(0,0.12), t(0u), t(1u))+vec2f(t(2u)*band(p.y+0.42,0.1), t(2u)*0.4);
        }
        case 70u: { // Arch Opening
            var light = vec2f(0);
            let n = max(1.0, t(0u));
            for (var i=0u; i<5u; i++) {
                if f32(i) >= n { break; }
                let x = (f32(i)-(n-1.0)*0.5)*mix(0.18,0.4,t(2u));
                let v = p-vec2f(x, 0.05);
                let arch = max(length(vec2f(v.x, min(v.y+0.05,0.0)))-t(2u)*0.35, v.y-t(1u)*0.35);
                light = max(light, vec2f(1.0-smoothstep(-0.01,0.01,arch), band(arch,0.02)));
            }
            return light+vec2f(t(3u)*0.15, t(3u)*0.4);
        }
        case 71u: { // Oculus
            let radius = t(0u)*0.38;
            let d = r-radius;
            let disc = 1.0-smoothstep(-0.012,0.006,d);
            let dome = mix(0.3, 1.0, 0.62-p.y)*t(1u);
            return vec2f(disc*dome+band(d,0.055)*0.38, disc*(0.31-p.y)*t(2u)+band(d,0.01)*t(2u));
        }
        case 72u: { // Portal
            let d=box_distance(p-vec2f(0,0.07),vec2f(mix(0.08,0.22,t(1u)), mix(0.12,0.32,t(0u))), mix(0.02,0.12,t(2u)));
            let fill=1.0-smoothstep(-0.015,0.008,d);
            return (emitter(d,0.4)+vec2f(fill*0.82,fill*t(3u))) ;
        }
        case 73u: { // Pillar
            let v = rotate2(p, t(1u));
            return emitter(v.x, 0.71)*vec2f(mix(0.8,1.6,1.0/max(0.08,t(0u))), 0.72);
        }
        case 74u: { // Water Curtain
            let flow = mist(vec2f(p.x*5.0,p.y*mix(2.0,9.0,t(5u)))+drift*t(4u)+seed);
            let streaks = pow(0.5+0.5*cos(p.x*mix(20.0,90.0,t(5u))), 8.0);
            let shape = round(t(6u));
            var back = drifting_lights(p,time,seed+5.0,false);
            if shape < 0.5 { back = drifting_lights(p,time,seed+5.0,false); }
            else if shape < 1.5 { back = pow(0.5+0.5*cos(p.x*12.0+drift.x),4.0); }
            else { back = pow(0.5+0.5*cos(a*8.0),6.0)*exp(-2.0*r); }
            return vec2f(flow*t(0u)+streaks*0.3+back*t(2u)*0.22,
                streaks*t(1u)+flow*t(7u)+back*t(2u)*0.3)
                + vec2f(soft_grain(p,t(3u),time,seed));
        }
        case 75u: { // Event Horizon
            let shift = camera_shift(drift, t(3u), time);
            let v = p-shift;
            let rv = length(v);
            let radius = mix(0.16, 0.42, t(5u));
            let d = rv-radius;
            let disk = band(v.y-v.x*mix(-0.4,0.4,t(6u)),0.028)*exp(-9.0*abs(v.x))*t(7u);
            let stars = drifting_lights(v,time,seed+7.0,true)*t(1u);
            let heat = band(v.y,0.05)*t(8u)*0.18;
            return (emitter(d, 0.7+t(2u))+vec2f(disk,disk*0.60)*step(radius*0.72,rv)
                + vec2f(stars*0.16, stars)+vec2f(heat,heat*0.4))*mix(0.5,1.5,t(0u))
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 76u: { // Static Glass
            let d=box_distance(p,vec2f(0.38,0.18),0.03);
            let inside=1.0-smoothstep(-0.01,0.013,d);
            let stat = hash(floor(p*mix(20.0,120.0,t(1u)))+floor(fract(time / 6.283185307)*round(mix(2.0,12.0,t(9u)))))*t(1u);
            let smoke = mist(p*mix(2.0,5.0,t(2u))+drift*0.2+seed)*t(2u)*0.2;
            let marks = ink_scene(p,t(5u),t(6u),t(7u),t(8u),t(9u),t(10u),t(11u),time,seed);
            return vec2f(inside*t(0u)+stat+smoke, inside*t(3u)+stat*0.4+smoke*0.6)
                + marks + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 77u: { // Scan Bands
            let scan=pow(0.5+0.5*cos(p.y*mix(20.0, 220.0, t(0u))+drift.x*2.0),5.0)*t(1u);
            let sweep=band(p.y-0.26*drift.y, mix(0.04,0.2,t(2u)));
            let marks = ink_scene(p,t(5u),t(6u),t(7u),t(8u),t(9u),t(10u),t(11u),time,seed);
            return vec2f(scan*0.4+sweep*0.5, scan*sweep+t(3u)*mist(p*3.0))
                + marks + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 78u: { // Scan Panel
            let d=box_distance(p,vec2f(0.38,0.18),0.03);
            let inside=1.0-smoothstep(-0.01,0.013,d);
            let scan=pow(0.5+0.5*cos(p.y*170.0+drift.x*2.0),5.0)*t(1u);
            let sweep=band(p.y-0.3*drift.y+0.08*sin(time)*t(2u), 0.03)*t(2u);
            let lp = p-vec2f(t(5u),t(6u))*0.12-vec2f(0.08,-0.06);
            let lights = exp(-26.0*dot(lp,lp));
            return vec2f(inside*t(0u)+scan*0.38+sweep*0.3+lights*0.16,
                inside*scan+band(d,0.014)*t(3u)+sweep*0.5+lights*0.42)
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 79u: { // Two Inks
            let rolled = rotate2(p, t(1u)*18.0);
            let haze=mist(rolled*4.0+vec2f(t(5u),t(6u))+seed);
            let ink=smoothstep(0.34,0.57,haze)*t(0u)+t(3u)*pow(0.5+0.5*cos(rolled.x*90.0),6.0)*0.18;
            let marks = ink_scene(p,t(5u),t(6u),t(7u),t(8u),t(9u),t(10u),t(11u),time,seed);
            return vec2f(ink*0.65,(1.0-ink)*haze*t(2u))+marks
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 80u: { // Smoke Columns
            let n = max(3.0, t(0u));
            var smoke = 0.0;
            for (var i=0u; i<9u; i++) {
                if f32(i) >= n { break; }
                let x = (f32(i)-(n-1.0)*0.5)*0.16;
                smoke += mist(vec2f((p.x-x)*8.0, p.y*3.0+0.5*sin(time)*t(2u))+seed)*exp(-abs(p.x-x)*6.0);
            }
            let marks = ink_scene(p,t(5u),t(6u),t(7u),t(8u),t(9u),t(10u),t(11u),time,seed);
            return vec2f(smoke*t(1u), smoke*0.5+t(3u)*hash(p*40.0))+marks
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 81u: { // Ink Halftone
            let haze=mist(p*4.0+vec2f(t(5u),t(6u))*0.4+seed);
            let dots=length(fract(p*mix(24.0, 90.0, t(1u)))-0.5);
            let mask=1.0-smoothstep(haze*0.55-0.06,haze*0.55+0.04,dots);
            let scan = pow(0.5+0.5*cos(p.y*90.0),4.0)*t(3u)*0.2;
            let marks = ink_scene(p,t(5u),t(6u),t(7u),t(8u),t(9u),t(10u),t(11u),time,seed);
            return vec2f(mask*haze*t(0u)+scan, mask*haze*t(2u))+marks
                + vec2f(soft_grain(p,t(4u),time,seed));
        }
        case 82u: { // Gradient Sweep
            let v = rotate2(q, t(0u)*50.0+drift.x*20.0);
            let ramp = smoothstep(-t(2u)*0.4, t(2u)*0.4, v.x);
            return vec2f(mix(ramp, smoothstep(0.0,1.0,ramp), t(1u)), pow(ramp,2.0));
        }
        case 83u: { // Light Field
            let field = mist(p*mix(1.5, 6.0, t(0u))+drift*t(1u)*2.0+seed);
            return vec2f(field, field*field)*mix(0.4, 1.6, t(2u));
        }
        case 84u: { // Flow
            let n = mist(p*t(0u)*3.0+drift*t(2u)+seed);
            let c = pow(n, mix(0.6, 2.4, t(1u)/2.0));
            return vec2f(c, c*c);
        }
        case 85u: { // Silk Wave
            let v = rotate2(p, t(2u));
            let flow = v.y*t(0u)*3.2 + sin(v.x*4.0+drift.x)*2.0;
            let folds = sin(flow);
            let body = pow(folds*0.5+0.5, mix(0.8, 3.0, t(1u)));
            return vec2f(body, pow(folds*0.5+0.5, 7.0));
        }
        case 86u: { // Glitter
            return glitter_field(p, t(0u), t(1u), t(2u), time, seed);
        }
        case 87u: { // Echo
            let c = vec2f(0.0, t(2u)*0.4);
            var rings = 0.0;
            let n = t(0u);
            for (var i=0u; i<8u; i++) {
                if f32(i) >= n { break; }
                rings += band(length(p-c)-f32(i)*0.08 - fract(time / 6.283185307)*0.2, mix(0.01,0.06,t(1u)));
            }
            return vec2f(rings*0.6, rings);
        }
        case 88u: { // Plasma
            let s = t(0u);
            let swirl = t(1u);
            let n = mist(rotate2(p*s, swirl*40.0+time*20.0)+seed);
            let c = pow(n, mix(0.5, 2.8, t(2u)));
            return vec2f(c, c*c*1.1);
        }
        case 89u: { // Threshold
            let floorv = smoothstep(t(2u)-0.15, t(2u)+0.05, p.y)*t(0u);
            let wall = band(abs(p.x)-0.42, 0.08)*t(1u);
            return vec2f(floorv*0.7+wall, floorv+wall);
        }
        case 90u: { // Fog Bank
            let fog = mist(p*mix(1.4,4.5,t(1u))+drift*0.4+seed);
            let bandh = exp(-abs(p.y-t(0u))*mix(1.5, 8.0, t(1u)));
            return vec2f(fog*bandh, fog*bandh*t(2u));
        }
        case 91u: { // Corridor
            var light = vec2f(0);
            let frames = max(3.0, t(1u));
            for (var i=0u; i<10u; i++) {
                if f32(i) >= frames { break; }
                let index = f32(i);
                let size = t(0u)*0.38*pow(0.78,index);
                let d = box_distance(p, vec2f(size*1.15, size), 0.01);
                light = max(light, emitter(d, t(2u))*(1.0-index/frames));
            }
            return light;
        }
        case 92u: { // Pool
            let c = vec2f(0.0, t(2u)*0.35);
            let d = length(p-c)-t(0u)*0.35;
            let fill = 1.0-smoothstep(-mix(0.02,0.16,t(1u)), 0.02, d);
            return vec2f(fill*0.65, fill*0.35+band(d,0.03));
        }
        case 93u: { // Glass Orb
            let radius = t(0u)*0.45;
            let d = r-radius;
            let fill = 1.0-smoothstep(-0.01,0.01,d);
            return vec2f(fill*t(2u)*0.5+band(d,0.04)*t(1u), fill*t(2u)+band(d,0.01)*t(1u));
        }
        case 94u: { // Curved Horizon
            let curve = t(0u)*0.35*p.x*p.x;
            let y = p.y - t(2u) - curve;
            let glow = band(y, mix(0.04, 0.2, t(1u)));
            return vec2f(smoothstep(0.05,-0.2,y)*0.55+glow*0.4, glow);
        }
        case 95u: { // Twin Apertures
            let gap = t(1u)*0.35;
            let s = t(0u)*0.35;
            let a1 = length(p-vec2f(-gap,0.0))-s;
            let a2 = length(p-vec2f(gap,0.0))-s;
            let d = min(a1,a2);
            let fill = 1.0-smoothstep(-0.01,0.01,d);
            return vec2f(fill*0.6+band(d,0.04)*t(2u), fill*0.3+band(d,0.01)*t(2u));
        }
        case 96u: { // Light Columns
            let n = max(2.0, t(0u));
            var cols = 0.0;
            for (var i=0u; i<8u; i++) {
                if f32(i) >= n { break; }
                let x = (f32(i)-(n-1.0)*0.5)*mix(0.12,0.28,1.0-t(1u)*0.5);
                cols += band(p.x-x, mix(0.02,0.1,t(1u))) * (0.7+0.3*sin(time*3.0+f32(i))*t(4u));
            }
            return vec2f(cols*t(3u)*0.5+t(2u)*mist(p*3.0)*0.3, cols*t(3u));
        }
        case 97u, 98u: { // Advent paintings as lit canvas — not a copy of the source art
            let variant = f32(look - 97u);
            let qv = p + vec2f(variant * 0.13, -variant * 0.09);
            let canvas = 0.18+0.22*mist(qv*mix(3.0, 9.0, t(6u))+seed);
            let wash = smoothstep(-0.4, 0.5, qv.y+t(1u)*0.2)*t(0u);
            let shaft = exp(-3.5*pow((qv.x + variant * 0.1)*1.2,2.0))*t(2u)*(0.75+0.25*sin(time*3.0)*t(4u));
            let warmth = t(3u)*band(qv.y+0.2, 0.3);
            let bloom = t(7u)*mist(qv*2.0+drift);
            let body = canvas+wash*0.45+shaft*0.55+warmth*0.2;
            return vec2f(body, shaft+bloom+t(5u)*0.3);
        }
        case 99u: { // Ridge Drift
            let ridges = max(2.0, round(t(0u)));
            let haze_scale = mix(1.5, 3.6, t(1u));
            let slide = t(2u);
            var layers = 0.0;
            for (var i = 0u; i < 6u; i++) {
                if f32(i) >= ridges { break; }
                let layer = f32(i);
                let ridge_y = -0.32 + layer * 0.125
                    + 0.055 * sin(p.x * (2.2 + layer * 0.6) + layer * 2.1
                        + time * f32(1u + i) + seed * 0.1);
                layers = max(layers,
                    smoothstep(0.055, -0.025, p.y - ridge_y) * (1.0 - layer / ridges) * 0.62);
            }
            let haze = mist(p * haze_scale + vec2f(sin(time) * 0.14 * slide, 0.0) + seed);
            let light = band(p.y + 0.16 - 0.035 * sin(time), mix(0.035, 0.15, t(1u)));
            let body = haze * 0.34 + layers * (0.55 + 0.35 * t(1u)) + light * 0.22;
            return vec2f(body, light * (0.35 + 0.65 * slide) + layers * 0.22);
        }
        case 100u: { // Candle Field
            let candles = max(3.0, round(t(0u)));
            let flicker = t(1u);
            let halo = t(2u);
            var flames = 0.0;
            for (var i = 0u; i < 12u; i++) {
                if f32(i) >= candles { break; }
                let flame = f32(i);
                let x = (flame - (candles - 1.0) * 0.5) * mix(0.09, 0.16, halo);
                let y = -0.29 + 0.018 * sin(flame * 1.7 + seed);
                let d = length((p - vec2f(x, y)) * vec2f(1.0, 2.4));
                let pulse = 1.0 - flicker * 0.32 * (0.5 + 0.5 * sin(time * f32(1u + i % 3u) + flame));
                flames += exp(-d * d / mix(0.0009, 0.0065, halo)) * pulse;
            }
            let stars = glitter_field(p + vec2f(0.0, 0.28), 11.0, 0.18, flicker, time, seed + 31.0);
            let glow = mist(p * 2.6 + seed) * 0.16;
            return vec2f(flames * 0.6 + stars.x * 0.35 + glow,
                flames * 0.75 + stars.y * 0.5);
        }
        case 101u: { // Breathing Aperture
            let rings = max(2.0, round(t(0u)));
            let breath = 0.5 + 0.5 * sin(time);
            var aperture = 0.0;
            for (var i = 0u; i < 8u; i++) {
                if f32(i) >= rings { break; }
                let ring = f32(i);
                let radius = 0.09 + ring * mix(0.05, 0.11, t(1u)) + breath * 0.035;
                let d = abs(length(p * vec2f(1.0, 1.08)) - radius);
                aperture += band(d, mix(0.008, 0.05, t(2u))) * (1.0 - ring / rings * 0.5);
            }
            let centre = exp(-length(p) * mix(3.0, 9.0, t(2u)));
            return vec2f(aperture * 0.62 + centre * 0.22,
                aperture * 0.82 + centre * 0.18);
        }
        case 102u: { // Haze Wash
            let wash = mist((p + vec2f(sin(time) * 0.16 * t(1u), cos(time) * 0.03))
                * mix(0.8, 2.4, t(0u)) + seed);
            let lower = smoothstep(-0.10, 0.22, p.y);
            let bands = (0.5 + 0.5 * sin(p.y * mix(3.0, 9.0, t(0u))
                + wash * 2.0 + sin(time))) * mix(0.35, 1.0, lower);
            let light = band(p.y - 0.30 + 0.05 * sin(time * 2.0), mix(0.06, 0.24, t(2u)));
            return vec2f(wash * 0.38 + bands * (0.10 + 0.18 * t(2u)) + light * 0.22,
                light * (0.3 + 0.7 * t(2u)) + bands * 0.10);
        }
        case 103u: { // Iridescent Veil
            let veils = max(2.0, round(t(0u)));
            let v = rotate2(p, 28.0) + vec2f(sin(time) * 0.07 * t(2u), cos(time) * 0.05 * t(2u));
            var sheets = 0.0;
            for (var i = 0u; i < 6u; i++) {
                if f32(i) >= veils { break; }
                let sheet = f32(i);
                let offset = sheet * 0.09 - 0.18;
                let streak = band(v.x - offset + 0.12 * sin(v.y * 2.0 + time + sheet),
                    mix(0.02, 0.1, t(1u)));
                sheets += streak * (0.6 - 0.075 * sheet);
            }
            let lower = mix(0.05, 1.0, smoothstep(0.06, 0.34, p.y));
            sheets = sheets * lower;
            let shimmer = pow(0.5 + 0.5 * cos(v.x * mix(6.0, 16.0, t(1u)) + time * 2.0), 3.0) * t(1u) * lower;
            return vec2f(sheets * 0.58 + shimmer * 0.18,
                sheets * (0.2 + 0.4 * shimmer));
        }
        case 104u: { // Light Towers
            let towers = max(3.0, round(t(0u)));
            let spacing = mix(0.12, 0.22, t(1u));
            let width = mix(0.022, 0.075, t(1u));
            var columns = 0.0;
            for (var i = 0u; i < 10u; i++) {
                if f32(i) >= towers { break; }
                let tower = f32(i);
                let x = (tower - (towers - 1.0) * 0.5) * spacing;
                let wave = pow(0.5 + 0.5 * sin(p.y * mix(4.0, 12.0, t(2u))
                    - time * 2.0 + tower * 0.7), mix(1.5, 5.0, t(2u)));
                columns += band(p.x - x, width) * (0.35 + 0.65 * wave);
            }
            columns = columns * mix(0.18, 1.0, smoothstep(-0.12, 0.24, p.y));
            let haze = mist(p * 3.0 + vec2f(0.0, sin(time) * 0.1) + seed) * 0.2;
            return vec2f(columns * 0.68 + haze, columns * columns * 0.3 + haze * 0.4);
        }
        case 105u: { // Neon Drift
            let lines = max(3.0, round(t(0u)));
            let spread = mix(0.06, 0.13, t(1u));
            let v = rotate2(p, -32.0)
                + vec2f(sin(time) * 0.05 * t(1u), cos(time) * 0.04 * t(1u));
            var beams = 0.0;
            for (var i = 0u; i < 12u; i++) {
                if f32(i) >= lines { break; }
                let line = f32(i);
                let offset = (line - (lines - 1.0) * 0.5) * spread;
                beams += band(v.x - offset, mix(0.006, 0.024, t(2u)));
            }
            beams = beams * mix(0.01, 1.0, smoothstep(0.22, 0.46, p.y));
            let pulse = 0.75 + 0.25 * sin(time * 2.0 + seed);
            return vec2f(beams * 0.55 * pulse, beams * pulse * (0.2 + 0.8 * t(2u)));
        }
        case 106u: { // Warped Dream
            let warp = t(0u);
            let density = mix(10.0, 34.0, t(1u));
            let sharpness = mix(3.0, 10.0, t(2u));
            let y = p.y + 0.075 * sin(p.x * (2.0 + warp * 3.0) + time)
                + 0.04 * sin(p.x * 7.0 - time * 2.0) * warp;
            let streaks = pow(0.5 + 0.5 * sin(y * density + mist(p * 2.0 + seed) * 2.0), sharpness);
            let centre = band(p.y - 0.02 * sin(time), 0.12);
            return vec2f(streaks * 0.5 + mist(p * 2.5 + seed) * 0.18,
                streaks * centre * (0.25 + 0.75 * t(2u)));
        }
        case 107u: { // Violet Arc
            let curl = 0.30 + 0.06 * sin(p.x * 2.4 + time) * t(1u);
            let arc = band(p.y - curl, mix(0.02, 0.14, t(2u)))
                * smoothstep(-0.42, -0.02, p.y);
            let wash = mist(p * mix(1.4, 3.2, t(0u)) + vec2f(sin(time) * 0.08, 0.0) + seed);
            let pulse = 0.78 + 0.22 * sin(time * 2.0 + seed);
            return vec2f(wash * 0.32 + arc * 0.55 * pulse, arc * 0.72 * pulse + wash * 0.12);
        }
        case 108u: { // Amethyst Smoke
            let v = rotate2(p, 18.0) + vec2f(sin(time) * 0.10 * t(1u), cos(time) * 0.06 * t(1u));
            let smoke = pow(0.5 + 0.5 * sin(v.x * mix(2.5, 7.0, t(0u))
                + sin(v.y * mix(3.0, 8.0, t(1u)) + time) * mix(0.6, 2.2, t(2u))), 3.0);
            let lower = smoothstep(-0.02, 0.34, p.y);
            return vec2f(smoke * lower * 0.55 + mist(v * 2.0 + seed) * 0.20,
                smoke * lower * 0.58);
        }
        case 109u: { // Mint Aurora
            let v = p + vec2f(sin(time) * 0.12 * t(1u), 0.0);
            let curtain = pow(0.5 + 0.5 * sin(v.x * mix(3.0, 10.0, t(0u))
                + sin(v.y * 4.0 + time) * 1.2), mix(3.0, 10.0, t(2u)));
            let light = exp(-abs(v.y - 0.26) / mix(0.04, 0.18, t(2u)));
            let lower = smoothstep(0.02, 0.32, p.y);
            return vec2f(curtain * light * lower * 0.62 + mist(v * 2.2 + seed) * 0.18,
                curtain * light * lower * 0.72);
        }
        case 110u: { // Glow Night
            let v = p * mix(0.6, 1.6, t(0u))
                + vec2f(0.0, sin(time) * 0.08 * t(1u));
            let lights = drifting_lights(v, time, seed, false) * mix(0.5, 1.0, t(2u));
            let lower = smoothstep(0.06, 0.38, p.y);
            return vec2f(lights * lower * 0.42 + mist(v * 2.4 + seed) * 0.22,
                lights * lower * 0.55);
        }
        case 111u: { // Canyon Rays
            let side = smoothstep(0.16, 0.42, abs(p.x));
            let origin = vec2f(sign(p.x) * mix(0.20, 0.34, t(1u)), 0.30);
            let rays = radial_rays(p - origin, mix(2.0, 10.0, t(0u)), 0.35, t(2u), seed, drift);
            let lower = smoothstep(0.02, 0.34, p.y);
            let shafts = rays.y * side * lower * mix(0.4, 1.0, t(0u));
            return vec2f(shafts * 0.62 + mist(p * 2.6 + seed) * 0.20, shafts * 0.75);
        }
        case 112u: { // Planet Limb
            let curve = p.y - 0.44 + t(0u) * 0.12 * p.x * p.x + 0.02 * sin(time);
            let limb = band(curve, mix(0.008, 0.05, t(2u)));
            let atmosphere = exp(-abs(curve) / mix(0.05, 0.18, t(1u)));
            let body = smoothstep(0.02, -0.10, curve) * 0.45;
            let bands = pow(0.5 + 0.5 * sin(p.x * mix(5.0, 14.0, t(0u))
                + curve * 8.0 + time), 4.0) * atmosphere;
            return vec2f(body + atmosphere * 0.28 + bands * 0.16, limb * 0.85 + bands * 0.25);
        }
        case 113u: { // Treelight
            let trees = max(3.0, round(t(0u)));
            var trunks = 0.0;
            for (var i = 0u; i < 12u; i++) {
                if f32(i) >= trees { break; }
                let tree = f32(i);
                let x = (tree - (trees - 1.0) * 0.5) * 0.11;
                let sway = sin(time * 0.8 + tree * 0.7) * 0.025 * t(1u) * (p.y + 0.2);
                trunks += band(p.x - x - sway, 0.014) * smoothstep(0.08, 0.36, p.y);
            }
            let lower = smoothstep(0.06, 0.36, p.y);
            let lights = glitter_field(p + vec2f(sin(time) * 0.04 * t(1u), 0.0),
                14.0, t(2u), 0.2, time, seed).y;
            return vec2f(trunks * 0.35 + lights * lower * 0.35,
                lights * lower * 0.5 + trunks * 0.12);
        }
        case 114u: { // Cloud Bank
            let v = p * mix(1.8, 4.2, t(0u))
                + vec2f(sin(time) * 0.12 * t(1u), cos(time) * 0.05 * t(1u));
            let billow = smoothstep(0.38, 0.76, mist(v + vec2f(0.0, 1.7) + seed));
            let bank = billow * smoothstep(0.04, 0.34, p.y);
            let edge = band(v.y - 2.2, mix(0.12, 0.4, t(2u))) * bank;
            return vec2f(bank * 0.55 + edge * 0.18, edge * 0.42 + bank * 0.16);
        }
        case 115u: { // Blue Ripple
            let c = vec2f(0.0, 0.36);
            let d = length((p - c) * vec2f(1.6, 1.0));
            let ripple = pow(0.5 + 0.5 * sin(d * mix(12.0, 34.0, t(0u))
                - time * mix(1.0, 3.0, t(1u))), mix(3.0, 10.0, t(2u)));
            let fade = exp(-d * mix(1.4, 3.2, t(2u)));
            let lower = smoothstep(0.02, 0.32, p.y);
            return vec2f(ripple * fade * lower * 0.62 + mist(p * 2.4 + seed) * 0.14,
                ripple * fade * lower * 0.78);
        }
        case 116u: { // Deep Flow
            let v = rotate2(p, 12.0) + vec2f(sin(time) * 0.12 * t(1u), cos(time) * 0.04 * t(1u));
            var ribbons = 0.0;
            for (var i = 0u; i < 4u; i++) {
                let ribbon = f32(i);
                let offset = (ribbon - 1.5) * 0.14;
                let wave = v.y + 0.16 * sin(v.x * mix(3.0, 8.0, t(0u)) + time * 0.8 + ribbon * 1.1);
                ribbons += band(wave - offset, mix(0.02, 0.10, t(2u))) * (0.7 - 0.1 * ribbon);
            }
            let lower = smoothstep(0.04, 0.34, p.y);
            return vec2f(ribbons * lower * 0.55 + mist(v * 2.2 + seed) * 0.18,
                ribbons * lower * 0.65);
        }
        case 117u: { // Glowing Leaves
            let drift_leaves = vec2f(sin(time) * 0.14 * t(1u), cos(time) * 0.05 * t(1u));
            let leaves = glitter_field(p + drift_leaves + vec2f(0.0, 0.24),
                t(0u) * 24.0, t(2u), 0.35, time, seed + 17.0);
            let lower = smoothstep(0.06, 0.36, p.y);
            return vec2f(leaves.x * lower * 0.42 + mist(p * 2.6 + seed) * 0.20,
                leaves.y * lower * 0.60);
        }
        case 118u: { // Golden Wheat
            let stalks = max(6.0, round(t(0u)));
            var wheat = 0.0;
            for (var i = 0u; i < 18u; i++) {
                if f32(i) >= stalks { break; }
                let stalk = f32(i);
                let x = (stalk - (stalks - 1.0) * 0.5) * mix(0.05, 0.11, t(1u));
                let sway = sin(time * 0.7 + stalk * 0.9) * 0.028 * t(2u) * (p.y + 0.15);
                wheat += band(p.x - x - sway, mix(0.004, 0.014, t(2u)))
                    * smoothstep(0.10, 0.36, p.y);
            }
            let haze = mist(p * 2.0 + seed) * 0.18;
            return vec2f(wheat * 0.5 + haze, wheat * 0.45 + haze * 0.3);
        }
        default: { return vec2f(0); }
    }
}

// Looks whose geometry is otherwise static still need to respond to the Motion
// tab, so give them a small seamless camera sway and light pulse.
const static_looks = array<u32, 32>(
    9u, 12u, 15u, 16u, 17u, 19u, 22u, 23u, 24u, 28u,
    47u, 51u, 54u, 55u, 59u, 66u, 67u, 68u, 69u, 70u,
    71u, 72u, 73u, 75u, 79u, 81u, 89u, 91u, 92u, 93u,
    94u, 95u
);

fn motion_look(look: u32, uv: vec2f, time: f32, drift: vec2f, seed: f32) -> vec2f {
    var static_look = false;
    for (var i = 0u; i < 32u; i++) {
        if (look == static_looks[i]) { static_look = true; break; }
    }
    if (!static_look) { return library_look(look, uv, time, drift, seed); }
    let amount = length(drift);
    if (amount < 0.001) { return library_look(look, uv, time, drift, seed); }
    let sway = drift * 0.014 + vec2f(sin(time), cos(time)) * 0.006 * amount;
    let light = library_look(look, uv + sway, time, drift, seed);
    return light * max(0.0, 1.0 + 0.10 * amount * sin(time + seed));
}
