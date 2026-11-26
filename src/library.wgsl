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

fn library_look(look: u32, uv: vec2f, time: f32, drift: vec2f, seed: f32) -> vec2f {
    let q = uv-0.5;
    let aspect = settings.composition;
    let p = q*vec2f(max(1.0,aspect),max(1.0,1.0/aspect));
    let r = length(p);
    let a = atan2(p.y,p.x);
    let cam = drift * (0.35 + t(3u)*1.4);
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
            let v = p-origin;
            let ray = pow(0.5+0.5*cos(atan2(v.y,v.x)*n*2.0+drift.y*t(6u)+seed), mix(3.0,18.0,1.0-t(7u)));
            let taper = exp(-length(v)*1.6)*(0.4+t(1u)*mist(v*5.0));
            return vec2f(taper*(0.2+ray)*t(0u), taper*ray*t(2u));
        }
        case 8u: { // Planet Rise
            let size = mix(0.18, 0.48, t(5u));
            let v = vec2f(p.x, p.y-mix(-0.15,0.45,t(8u)));
            let d = length(v)-size;
            let rim = emitter(d, t(2u));
            let atmo = band(d-mix(0.02,0.12,t(6u)), 0.08)*t(6u);
            let rings = band(abs(v.y)-size*0.15, mix(0.01,0.05,t(7u)))*t(7u)*step(abs(v.x), size*1.4);
            return (rim+vec2f(atmo,atmo)+vec2f(rings*0.4,rings))*mix(0.45,1.4,t(0u));
        }
        case 9u: { // Light Corridor
            var light = vec2f(0);
            let frames = 7.0;
            for (var i=0u; i<7u; i++) {
                let index = f32(i);
                let size = 0.33*pow(0.75,index)*(0.8+t(6u)*0.5);
                let v = p+vec2f(0,0.014*index);
                let d = box_distance(v,vec2f(size*mix(0.8,1.6,t(7u)),size), mix(0.0,0.04,t(5u)));
                light = max(light,emitter(d,0.91-index*0.065)*(0.95-index*0.075));
            }
            return light*mix(0.5,1.4,t(0u))+vec2f(0.0, t(2u)*band(p.y+0.45,0.08));
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
        case 11u: { // Long Exposure
            let v = rotate2(p, t(1u));
            let streaks = t(0u);
            let d = v.x + 0.14*sin(v.y*streaks+drift.y*t(4u));
            return emitter(d, mix(0.2,0.9,t(2u))) * vec2f(1.0, mix(0.4,1.2,t(2u)));
        }
        case 12u: { // Glass Fins
            var output = vec2f(0);
            let fins = clamp(round(t(5u)), 3.0, 13.0);
            for (var n=0u; n<13u; n++) {
                if f32(n) >= fins { break; }
                let i=f32(n)-(fins-1.0)*0.5;
                var v=p-vec2f(i*mix(0.04,0.12,t(8u)),0);
                v.x += v.y*0.16;
                let size=vec2f(mix(0.008,0.04,t(6u)), mix(0.12,0.36,t(7u)));
                let d=box_distance(v,size,0.008);
                output=max(output,vec2f(1.0-smoothstep(-0.02,0.014,d),band(d,0.02))*mix(0.4,1.3,t(0u)));
            }
            return output+vec2f(t(2u)*0.12, t(1u)*0.2);
        }
        case 13u: { // Glass Torus
            let radius = mix(0.16, 0.42, t(5u));
            let thick = mix(0.02, 0.12, t(6u));
            let twist = t(7u);
            let wave = 0.034*sin(a*twist+drift.y);
            let rim = r-radius-wave*t(8u);
            let facet = 0.25+0.75*pow(cos(a*3.0+drift.x),2.0);
            return vec2f(band(rim,thick*1.6),band(rim,thick*0.35))*facet*mix(0.5,1.4,t(0u));
        }
        case 14u: { // Hanging Blades
            var output = vec2f(0);
            let blades = clamp(round(t(0u)), 3.0, 14.0);
            for (var n=0u; n<14u; n++) {
                if f32(n) >= blades { break; }
                let i=f32(n)-(blades-1.0)*0.5;
                let chase = sin(time*max(0.5,t(3u))+i)*t(1u)*0.08;
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
            return vec2f(fill*0.7+band(d,0.04), fill*t(3u)+band(d,0.01));
        }
        case 17u: { // Bottom Glow
            let h = mix(0.04, 0.55, t(0u));
            let soft = mix(0.04, 0.22, t(1u));
            let breathe = 0.85+0.15*sin(time*2.0)*t(2u);
            return vec2f(band(1.0-uv.y-0.05, h)*breathe, band(1.0-uv.y, soft)*breathe);
        }
        case 18u: { // Linear Drift
            let dir = rotate2(q, t(0u));
            let ramp=smoothstep(-t(1u), t(1u), dir.x+0.24*drift.x*t(2u));
            let contrast = mix(0.6, 1.6, t(4u));
            return vec2f(pow(ramp,contrast)*0.82, pow(ramp,contrast+0.6)*0.60);
        }
        case 19u: { // Edge Light
            let thick = t(0u);
            let d=min(0.5-abs(q.x),0.5-abs(q.y));
            return vec2f(band(d, mix(0.04,0.18,t(1u))), band(d, mix(0.01,0.05,1.0-t(1u)))) * (0.7+t(2u)*0.4);
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
            let slat = pow(0.5+0.5*cos(p.x*bars*1.8+time*t(2u)*4.0), mix(2.0,10.0,1.0-t(1u)));
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
            return emitter(d,t(2u))+vec2f(spokes*0.67, (1.0-smoothstep(-0.008,0.005,d))*0.64);
        }
        case 26u: { // Silhouette Cross
            let v=p+vec2f(0,0.025);
            let d=min(box_distance(v,vec2f(0.024,0.32),0.006), box_distance(v+vec2f(0,0.087),vec2f(0.18,0.021),0.005));
            let solid=1.0-smoothstep(-0.008,0.005,d);
            let spokes=pow(0.5+0.5*cos(a*21.0+drift.x),7.0)*exp(-6.0*r)*t(3u);
            return (emitter(d,t(2u))+vec2f(spokes,spokes*0.34))*(1.0-solid*0.85);
        }
        case 27u: { // Glass Cross
            let v=p+vec2f(0,0.025);
            let d=min(box_distance(v,vec2f(mix(0.016,0.05,t(6u)), mix(0.2,0.38,t(5u))), mix(0.0,0.02,t(10u))),
                      box_distance(v+vec2f(0,0.08),vec2f(mix(0.12,0.24,t(5u)), mix(0.014,0.04,t(6u))),0.005));
            return emitter(d,t(0u))*vec2f(0.7,0.5+0.5*sin(p.y*18.0+drift.y));
        }
        case 28u: { // Curtain Streaks · Cross
            let curtain=pow(0.5+0.5*cos(p.x*mix(40.0,160.0,t(0u))), mix(4.0,14.0,t(1u)))*band(p.y,0.33);
            let v=p+vec2f(0,0.025);
            let d=min(box_distance(v,vec2f(0.024,0.32),0.006), box_distance(v+vec2f(0,0.087),vec2f(0.18,0.021),0.005));
            return vec2f(curtain*0.58,curtain*0.32)+emitter(d,0.77)*t(4u);
        }
        case 29u: { // Light Threads
            return vec2f(band(p.y+0.11*sin(p.x*6.0+drift.x), mix(0.08,0.3,t(7u)))*0.2, drifting_lights(p, time, seed, true)*t(0u));
        }
        case 30u: { // Snow Glint
            let fine=drifting_lights(p, time+0.4,seed,true)*t(0u);
            return vec2f(band(q.y-0.45,0.13)*t(1u), fine+drifting_lights(p+drift*0.04,time,seed+3.0,true)*t(3u));
        }
        case 31u: { // Embers & Snow
            let embers=drifting_lights(p*0.9, time*mix(0.4,2.2,t(3u)), seed, false)*t(0u);
            let snow=drifting_lights(p+vec2f(0,time*0.2), time, seed+8.0, true)*t(1u);
            return vec2f(embers*0.45+snow*0.2, embers+snow*0.6)* (0.6+t(2u));
        }
        case 32u: { // Amber Bokeh
            let bokeh=drifting_lights(p*mix(0.5,1.2,t(3u)),time,seed,false)*t(0u);
            return vec2f(bokeh*0.45, bokeh*(0.6+t(2u))+drifting_lights(p*2.0,time,seed+2.0,true)*t(1u));
        }
        case 33u: { // Breathing Stars
            let cells=p*mix(8.0, 22.0, t(5u));
            let center = fract(cells)-0.5;
            let twinkle=pow(0.5+0.5*sin(hash(floor(cells)+seed)*6.2831853+time*t(4u)),3.0);
            let star=band(center.x, mix(0.02,0.08,t(8u)))*band(center.y,0.18)+band(center.y,0.03)*band(center.x,0.18);
            return vec2f(drifting_lights(p,time,seed,true)*t(0u)*0.2, star*twinkle*t(1u));
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
            return grid_cells(p, cols, rows, t(4u), seed, time*t(2u))*vec2f(t(3u)+0.4, 1.0);
        }
        case 39u: { // Panel Mosaic
            return grid_cells(p, t(0u), mix(4.0,18.0,t(3u)), t(1u), seed, time)*vec2f(0.7+t(4u), 0.5+t(2u));
        }
        case 40u: { // Silk Light
            let ribbon = emitter(p.y+0.14*sin(p.x*mix(1.0,6.0,t(7u))+drift.y)*t(6u), t(1u));
            return max(ribbon, emitter(p.y-0.17*sin(p.x*3.0)+0.12, 0.54))*mix(0.5,1.4,t(0u));
        }
        case 41u: { // Caustic Depths
            let haze=mist(p*4.0+drift*mix(0.2,1.2,t(3u))+seed);
            let caustic=pow(0.5+0.5*sin(p.x*22.0+4.0*haze+drift.x+p.y*1.2), mix(3.0, 11.0, t(2u)));
            return vec2f(caustic*haze,caustic*haze*haze)*mix(0.4,1.4,t(0u));
        }
        case 42u: { // Deep Field
            let haze=mist(p*mix(2.0,7.0,t(1u))+drift*0.6+seed);
            return vec2f(haze*mix(0.4,1.2,t(0u)), smoothstep(0.45,0.72,haze)*t(2u));
        }
        case 43u: { // Volume Rays
            return radial_rays(p-vec2f(-0.22,-0.48), mix(4.0, 22.0, t(2u)), mix(0.3,1.0,t(1u)), 0.35, seed, drift*t(3u))*mix(0.4,1.5,t(0u));
        }
        case 44u: { // Ramp Squares
            var light = vec2f(0);
            for (var i=0u; i<7u; i++) {
                let index = f32(i);
                let size = mix(0.12,0.4,t(5u))*pow(0.75,index);
                let v = p+vec2f(sin(index+drift.y)*size*0.22,0);
                let d = box_distance(v,vec2f(size), mix(0.0,0.08,t(6u)));
                light = max(light,emitter(d,0.9-index*0.08));
            }
            return light*mix(0.5,1.5,t(0u));
        }
        case 45u: { // Glass Ripple
            let wave = 0.034*sin(a*mix(2.0,12.0,t(5u))+drift.y)+0.012*cos(a*9.0);
            let optical = pow(0.5+0.5*cos(mix(20.0, 80.0, t(6u))*(r+wave)+drift.x),4.0);
            let falloff=1.0-smoothstep(0.27,0.43,r);
            return vec2f(optical*falloff,optical*falloff*(0.49+t(2u)))*mix(0.5,1.4,t(0u));
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
            let tilt = rotate2(p, t(3u));
            return vec2f(band(d,0.044)*0.35,band(d, mix(0.008,0.03,t(2u)))*dots*0.75)*step(length(tilt)-0.02, radius+0.08);
        }
        case 50u: { // Phase Rings
            let rings = pow(0.5+0.5*cos(r*t(0u)*12.0+0.8*sin(3.0*a)+drift.y*t(1u)), mix(4.0, 14.0, 1.0-t(2u)));
            return vec2f(rings*0.7,rings*0.83)*exp(-1.5*r);
        }
        case 51u: { // Wire Sphere
            let s = t(0u);
            let v=p/max(0.2,s*0.5);
            let z=sqrt(max(0.0,1.0-dot(v,v)));
            let longitude=atan2(v.x,z);
            let latitude=asin(clamp(v.y,-1.0,1.0));
            let line=max(band(fract((longitude+drift.x*0.34)*t(1u)*0.25)-0.5,0.09),band(fract(latitude*t(1u)*0.25)-0.5,0.085));
            let mask=(1.0-smoothstep(0.96,1.0,length(v)))*0.82;
            return vec2f(line,line)*mask*t(2u);
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
            let pulse = 0.5+0.5*sin(time*mix(1.0,8.0,t(1u))+random*20.0)*t(2u);
            return vec2f(trace*step(0.48,random), trace*pulse);
        }
        case 61u: { // Ripple Floor
            let depth = max(0.008,q.y-t(2u));
            let ripple=band(fract(length(p-vec2f(0,0.53))*t(0u)*1.8+0.18*drift.x)-0.5,0.064);
            let ground=ripple*smoothstep(0.018,0.40,depth);
            return vec2f(ground*0.85, ground*t(1u));
        }
        case 62u: { // Chalk Smear
            let v=vec2f(p.x+p.y*0.8,p.y);
            let stroke=mist(v*vec2f(mix(12.0, 60.0, t(3u)/16.0),5.0)+drift*t(2u)+seed);
            let mark=smoothstep(0.36,0.72,stroke*mist(p*3.0)*1.55)*t(0u);
            return vec2f(mark*0.58, mark*t(1u)+t(5u)*hash(floor(p*80.0)));
        }
        case 63u: { // Failing Ceiling
            return grid_cells(p, mix(4.0,16.0,t(5u)), mix(3.0,12.0,t(5u)), 0.12, seed, time*t(3u))*vec2f(t(0u), t(2u))*(0.5+t(8u)*hash(floor(p*9.0)+floor(time*2.0)));
        }
        case 64u: { // Office Ceiling
            return grid_cells(p, 12.0, 8.0, 0.08, seed, time)*vec2f(t(0u)+0.3, t(1u)+0.3);
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
            return opening_mask(p, t(0u), t(4u))*vec2f(0.8, t(2u));
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
            return vec2f(flow*t(0u)+streaks*0.3, streaks*t(1u)+flow*t(7u));
        }
        case 75u: { // Event Horizon
            let radius = mix(0.16, 0.42, t(5u));
            let d = r-radius;
            let disk = band(p.y-p.x*mix(-0.4,0.4,t(6u)),0.028)*exp(-9.0*abs(p.x))*t(7u);
            return emitter(d, 0.7+t(2u))+vec2f(disk,disk*0.60)*step(radius*0.72,r);
        }
        case 76u: { // Static Glass
            let d=box_distance(p,vec2f(0.38,0.18),0.03);
            let inside=1.0-smoothstep(-0.01,0.013,d);
            let stat = hash(floor(p*mix(20.0,120.0,t(1u))+floor(time*12.0*t(9u))))*t(1u);
            return vec2f(inside*t(0u)+stat, inside*t(3u)+stat*0.4);
        }
        case 77u: { // Scan Bands
            let scan=pow(0.5+0.5*cos(p.y*mix(20.0, 220.0, t(0u))+drift.x*2.0),5.0)*t(1u);
            let sweep=band(p.y-0.26*drift.y, mix(0.04,0.2,t(2u)));
            return vec2f(scan*0.4+sweep*0.5, scan*sweep+t(3u)*mist(p*3.0));
        }
        case 78u: { // Scan Panel
            let d=box_distance(p,vec2f(0.38,0.18),0.03);
            let inside=1.0-smoothstep(-0.01,0.013,d);
            let scan=pow(0.5+0.5*cos(p.y*170.0+drift.x*2.0),5.0)*t(1u);
            return vec2f(inside*t(0u)+scan*0.38, inside*scan+band(d,0.014)*t(3u));
        }
        case 79u: { // Two Inks
            let haze=mist(p*4.0+vec2f(t(5u),t(6u))+seed);
            let ink=smoothstep(0.34,0.57,haze)*t(0u);
            return vec2f(ink*0.65,(1.0-ink)*haze*t(2u));
        }
        case 80u: { // Smoke Columns
            let n = max(3.0, t(0u));
            var smoke = 0.0;
            for (var i=0u; i<9u; i++) {
                if f32(i) >= n { break; }
                let x = (f32(i)-(n-1.0)*0.5)*0.16;
                smoke += mist(vec2f((p.x-x)*8.0, p.y*3.0+time*t(2u))+seed)*exp(-abs(p.x-x)*6.0);
            }
            return vec2f(smoke*t(1u), smoke*0.5+t(3u)*hash(p*40.0));
        }
        case 81u: { // Ink Halftone
            let haze=mist(p*4.0+vec2f(t(5u),t(6u))*0.4+seed);
            let dots=length(fract(p*mix(24.0, 90.0, t(1u)))-0.5);
            let mask=1.0-smoothstep(haze*0.55-0.06,haze*0.55+0.04,dots);
            return vec2f(mask*haze*t(0u), mask*haze*t(2u));
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
                rings += band(length(p-c)-f32(i)*0.08 - fract(time)*0.2, mix(0.01,0.06,t(1u)));
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
            let canvas = 0.18+0.22*mist(p*mix(3.0, 9.0, t(6u))+seed);
            let wash = smoothstep(-0.4, 0.5, p.y+t(1u)*0.2)*t(0u);
            let shaft = exp(-3.5*pow(p.x*1.2,2.0))*t(2u)*(0.75+0.25*sin(time*3.0)*t(4u));
            let warmth = t(3u)*band(p.y+0.2, 0.3);
            let bloom = t(7u)*mist(p*2.0+drift);
            let body = canvas+wash*0.45+shaft*0.55+warmth*0.2;
            return vec2f(body, shaft+bloom+t(5u)*0.3);
        }
        default: { return vec2f(0); }
    }
}
