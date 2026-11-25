struct Params {
    size: vec2u,
    look: u32,
    seed: u32,
    phase: f32,
    energy: f32,
    intensity: f32,
    composition: f32,
    colors: array<vec4f, 3>,
}

@group(0) @binding(0) var<uniform> settings: Params;
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

@compute @workgroup_size(8,8)
fn render(@builtin(global_invocation_id) id: vec3u) {
    if (any(id.xy >= settings.size)) { return; }
    let uv = (vec2f(id.xy)+0.5)/vec2f(settings.size);
    let aspect = settings.composition;
    let p = (uv-0.5)*vec2f(aspect,1.0)/pow(max(aspect,1.0),0.42);
    let t = settings.phase*6.283185307;
    let drift = vec2f(cos(t),sin(t))*settings.energy;
    let seed = f32(settings.seed % 997u)*0.71;
    var body = 0.0;
    var glow = 0.0;
    switch settings.look {
        case 0u: {
            let ripple = sin(p.x*4.5+seed*0.3+drift.x)*0.14 + sin(p.x*8.0+drift.y)*0.064;
            let haze = mist(p*4.8+drift*0.65+seed);
            let veil = p.y+0.09+ripple+(haze-0.5)*0.24;
            body = exp(-11.0*abs(veil))*smoothstep(0.12,0.78,haze)*1.46;
            glow = exp(-88.0*pow(veil+0.035,2.0))*haze*0.8;
            body += 0.19*haze;
        }
        case 1u: {
            let flow = p.y*9.0 + sin(p.x*4.1+drift.x+seed)*2.2 + p.x*3.0;
            let folds = sin(flow+sin(flow*1.9+drift.y)*0.68);
            body = pow(folds*0.5+0.5, 1.6)*0.78;
            glow = pow(folds*0.5+0.5, 8.0)*0.46;
        }
        case 2u: {
            body = mist(p*2.2+drift*0.24+seed)*0.36;
            glow = drifting_lights(p, t, seed, false)*0.52;
        }
        case 3u: {
            let beam = exp(-4.0*pow(p.x + p.y*0.9 + drift.x*0.12,2.0));
            body = beam*mist(p*5.0+seed+drift)*0.65;
            glow = drifting_lights(p,t,seed+12.0,true)*beam*1.2;
        }
        case 4u: {
            let fog = mist(p*3.0+vec2f(0.75,0.38)*drift+seed);
            let wisps = mist(p*6.0+fog+drift*0.47+seed*1.6);
            body = smoothstep(0.22,0.82,fog)*0.84;
            glow = smoothstep(0.40,0.82,wisps)*body*0.58;
        }
        default: {
            let source = p-vec2f(-0.47+drift.x*0.07,-0.84);
            let angle = atan2(source.y,source.x);
            let ray = pow(0.5+0.5*sin(angle*26.0+seed*0.6+drift.y),6.0);
            let falloff = exp(-1.35*length(source));
            body = falloff*1.6*(0.3+0.83*ray);
            glow = falloff*ray*0.84;
        }
    }
    let vignette = max(0.38, 1.0-dot(uv-0.5,uv-0.5)*1.28);
    let strength = settings.intensity*vignette;
    let base = mix(settings.colors[0].rgb, settings.colors[1].rgb, clamp(body*strength,0.0,1.0));
    let color = mix(base, settings.colors[2].rgb, clamp(glow*strength,0.0,1.0));
    let dither = (hash(vec2f(id.xy))-0.5)/255.0;
    pixels[id.y*settings.size.x+id.x] = pack4x8unorm(vec4f(clamp(color+dither,vec3f(0),vec3f(1)),1));
}
