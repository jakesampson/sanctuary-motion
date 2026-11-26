struct Params {
    size: vec2u,
    look: u32,
    seed: u32,
    phase: f32,
    energy: f32,
    intensity: f32,
    composition: f32,
    colors: array<vec4f, 3>,
    surface: vec4u,
    tint: vec4f,
    glow: vec4f,
    gradient: array<vec4f, 4>,
    framing: vec4f,
    text_style: vec4u,
    text_flags: vec4u,
    text_layout: vec4f,
    text_shape: vec4f,
    text_color: vec4f,
    text_accent: vec4f,
    look_tune: array<vec4f, 4>,
    finish_tune: array<vec4f, 2>,
}

@group(0) @binding(0) var<uniform> settings: Params;

fn look_t(i: u32) -> f32 {
    return settings.look_tune[i / 4u][i % 4u];
}

fn finish_t(i: u32) -> f32 {
    return settings.finish_tune[i / 4u][i % 4u];
}
@group(0) @binding(1) var<storage, read_write> pixels: array<u32>;

fn hash(p: vec2f) -> f32 {
    return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453);
}

fn noise(p: vec2f) -> f32 {
    let cell = floor(p);
    let f = fract(p);
    let m = f*f*(3.0-2.0*f);
    return mix(mix(hash(cell), hash(cell + vec2f(1,0)), m.x),
               mix(hash(cell + vec2f(0,1)), hash(cell + 1.0), m.x), m.y);
}

fn mist(p: vec2f) -> f32 {
    return noise(p)*0.57 + noise(p*2.07+7.0)*0.26
        + noise(p*4.2+21.0)*0.12 + noise(p*8.7)*0.05;
}

fn drifting_lights(p: vec2f, t: f32, seed: f32, dust: bool) -> f32 {
    let scale = select(4.5, 11.0, dust);
    let cell = floor(p*scale);
    var light = 0.0;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let home = cell + vec2f(f32(x), f32(y));
            let key = home + seed;
            let offset = vec2f(hash(key), hash(key+9.1));
            let theta = t + hash(key+3.8)*6.2831853;
            let center = home + 0.17 + offset*0.66
                + vec2f(cos(theta), sin(theta))*0.19*settings.energy;
            let distance = length(p*scale-center);
            let radius = mix(0.15, 0.63, hash(key+8.0)) * select(1.0, 0.39, dust);
            let core = exp(-3.4*pow(distance/radius, 2.0));
            let edge = 1.0-smoothstep(radius*0.83, radius, distance);
            let flicker = 0.65 + 0.27*sin(theta+offset.y*6.0);
            light += mix(core, edge, select(0.32, 0.12, dust))*flicker;
        }
    }
    return light;
}

fn look_color(sample_uv: vec2f, phase: f32) -> vec3f {
    let uv = (sample_uv-0.5-settings.framing.yz)/settings.framing.x+0.5;
    let t = phase*6.283185307;
    let drift = vec2f(cos(t),sin(t))*settings.energy;
    let seed = f32(settings.seed % 997u)*0.71;
    let light = library_look(settings.look, uv, t, drift, seed);
    var body = light.x;
    var glow = light.y;
    let vignette = max(0.38, 1.0-dot(uv-0.5,uv-0.5)*1.28);
    let strength = settings.intensity*vignette;
    let base = mix(settings.colors[0].rgb, settings.colors[1].rgb, clamp(body*strength,0.0,1.0));
    let highlight = clamp(glow*strength,0.0,1.0);
    let legacy = mix(base,settings.colors[2].rgb,highlight);
    let palette = mix(mix(base,settings.glow.rgb,smoothstep(0.0,0.52,highlight)),
                      settings.colors[2].rgb,smoothstep(0.47,1.0,highlight));
    return select(legacy,palette,settings.glow.a>0.0);
}

fn color_mode(color: vec3f, uv: vec2f) -> vec3f {
    let light = max(max(color.r,color.g),color.b);
    if settings.surface.y==1u {
        let tint = settings.tint.rgb/max(0.001,max(max(settings.tint.r,settings.tint.g),settings.tint.b));
        return mix(color,tint*light,settings.tint.a);
    }
    if settings.surface.y!=2u { return color; }
    var position = uv.x;
    let q=uv-0.5;
    switch settings.surface.z {
        case 1u: { position=length(q)*1.85; }
        case 2u: { position=light; }
        case 3u: { position=0.5+0.5*sin((uv.x+uv.y*0.6)*12.0); }
        case 4u: { position=mist(uv*5.3)*1.25; }
        default: {}
    }
    let scaled=clamp(position,0.0,1.0)*3.0;
    let index=min(u32(scaled),2u);
    let ramp=mix(settings.gradient[index].rgb,settings.gradient[index+1u].rgb,scaled-f32(index));
    let baseline=max(max(settings.colors[0].r,settings.colors[0].g),settings.colors[0].b);
    let energy=clamp((light-baseline)*1.25,0.0,1.0);
    return settings.colors[0].rgb*0.55+ramp*energy;
}

@compute @workgroup_size(8,8)
fn render(@builtin(global_invocation_id) id: vec3u) {
    if (any(id.xy >= settings.size)) { return; }
    let uv = (vec2f(id.xy)+0.5)/vec2f(settings.size);
    let color = text_layer(color_mode(finish_color(uv, settings.surface.x),uv),uv);
    let dither = (hash(vec2f(id.xy))-0.5)/255.0;
    pixels[id.y*settings.size.x+id.x] = pack4x8unorm(vec4f(clamp(color+dither,vec3f(0),vec3f(1)),1));
}
