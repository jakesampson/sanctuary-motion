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

fn frame_glow(p: vec2f, half: vec2f, radius: f32, thick: f32, soft: f32) -> vec2f {
    let d = box_distance(p, max(half, vec2f(0.04)), radius);
    let depth = max(0.0, -d);
    let wash = exp(-depth/max(0.012, thick));
    let lip = exp(-pow(d/max(0.006, mix(0.01, 0.05, soft)), 2.0));
    return vec2f(wash*0.86+lip*0.4, lip+wash*0.5);
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
        case 5u: { // Light Rays — same family as Rays: fan from a high source
            return radial_rays(p-vec2f(0.0, mix(-0.55, 0.15, t(1u)*0.5+0.5)), t(0u), t(2u), 0.55, seed, drift);
        }
        case 6u: { // Bar Array — vertical LED columns with row gating
            let spacing = mix(6.0, 36.0, t(5u));
            let x = p.x*spacing + drift.x*t(3u)*6.0;
            let id = floor(x);
            let f = x-id-0.5;
            let bars = exp(-f*f*mix(10.0, 90.0, t(1u)));
            let rows = max(1.0, round(t(6u)));
            let h = mix(0.22, 1.05, t(8u));
            let rowm = 1.0-smoothstep(0.42, 0.5, abs(fract(p.y*rows+0.5)-0.5));
            let vert = pow(clamp(1.0-abs(p.y)/max(0.12,h), 0.0, 1.0), 1.4);
            let pat = round(t(7u));
            let chase = select(1.0, 0.35+0.65*step(0.5, fract(id*0.17+time*1.8)), pat>0.5);
            let haze = mist(p*2.4+seed)*t(2u)*0.35;
            let floor_y = 0.32;
            var body = bars*vert*rowm*chase*mix(0.45,1.35,t(0u))+haze;
            if p.y > floor_y {
                let fy = floor_y*2.0-p.y;
                let vert2 = pow(clamp(1.0-abs(fy)/max(0.12,h), 0.0, 1.0), 1.4);
                let bounce = bars*vert2*chase*exp(-(p.y-floor_y)*6.0)*0.45;
                body = bounce + haze*0.2;
            }
            return vec2f(body, body*0.85+t(4u)*hash(vec2f(id, floor(p.y*18.0)))*bars*0.4);
        }
        case 7u: { // Laser Planes — discrete sheets fanning from one origin through haze
            let n = max(2.0, round(t(5u)));
            let origin = vec2f(mix(-0.62, 0.62, t(8u)*0.5+0.5), mix(-0.48, 0.22, t(6u)));
            var light = vec2f(0.0);
            for (var i=0u; i<10u; i++) {
                if f32(i) >= n { break; }
                let k = f32(i)-(n-1.0)*0.5;
                let v = rotate2(p-origin, k*mix(6.0, 22.0, t(6u))+time*t(3u)*8.0);
                let sheet = exp(-abs(v.x)*mix(8.0, 36.0, t(7u)));
                let run = smoothstep(-1.1, 0.7, v.y)*exp(-abs(v.y)*0.28);
                light += vec2f(sheet*run, sheet*sheet*run)*(0.5+0.5*t(0u));
            }
            let haze = mist(p*3.2+drift+seed)*t(1u);
            return light*(0.55+haze*0.7)+vec2f(haze*0.18, t(2u)*0.22);
        }
        case 8u: { // Planet Rise — huge dark globe under the frame, lit limb + sky rings
            let rad = mix(0.82, 1.38, t(5u));
            let cy = mix(0.92, 0.42, t(8u));
            let v = vec2f(p.x, p.y-cy);
            let d = length(v)-rad;
            let planet = 1.0-smoothstep(-0.012, 0.004, d);
            let limb = exp(-abs(d)*mix(10.0, 36.0, 1.0-t(6u)));
            let glare = exp(-max(d,0.0)*mix(4.0, 14.0, 1.0-t(2u)))*(1.0-planet*0.92);
            var rings = 0.0;
            for (var i=0u; i<5u; i++) {
                let rr = rad+0.018+f32(i)*mix(0.012, 0.045, t(7u));
                rings += band(length(v)-rr, mix(0.003, 0.014, t(7u)))*step(0.0, d);
            }
            let sky = glare+rings*t(7u);
            return vec2f(sky*0.75+limb*0.35, sky+limb)*mix(0.5, 1.35, t(0u));
        }
        case 9u: { // Light Corridor — nested rounded frames receding to a point
            var light = vec2f(0.0);
            for (var i=0u; i<8u; i++) {
                let index = f32(i);
                let size = mix(0.16, 0.52, t(6u))*pow(0.72, index);
                let d = box_distance(p, vec2f(size*mix(1.05, 1.65, t(7u)), size), mix(0.0, 0.05, t(5u)));
                light = max(light, vec2f(band(d, 0.02), band(d, 0.006))*(1.0-index*0.08));
            }
            return light*mix(0.5, 1.4, t(0u))+vec2f(0.0, t(2u)*band(p.y+0.42, 0.1));
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
        case 11u: { // Long Exposure — streaks pulled along one heading
            let v = rotate2(p, t(1u));
            let n = max(0.4, t(0u));
            let pulled = pow(0.5+0.5*cos(v.x*n + sin(v.y*3.0+drift.y)*t(4u)*2.0), mix(2.5, 12.0, t(2u)));
            let span = smoothstep(-0.85, 0.2, 0.65-abs(v.y)*0.45);
            return vec2f(pulled*span, pulled*span);
        }
        case 12u: { // Glass Fins — perspective row of turning glass blades
            var output = vec2f(0);
            let fins = clamp(round(t(5u)), 3.0, 13.0);
            for (var n=0u; n<13u; n++) {
                if f32(n) >= fins { break; }
                let i=f32(n)-(fins-1.0)*0.5;
                let z = 0.62+abs(i)*0.09;
                let turn = sin(time*0.85+i*0.7)*1.2;
                let halfw = mix(0.01, 0.048, t(6u))*(abs(cos(turn))+0.18)/z;
                let halfh = mix(0.16, 0.4, t(7u))/z;
                let v = p-vec2f(i*mix(0.07,0.2,t(8u))/z, 0.02/z);
                let d=box_distance(v,vec2f(halfw,halfh),0.006);
                let facet = 0.28+0.72*pow(abs(sin(turn*2.0+v.y*10.0)),2.0);
                let fill = 1.0-smoothstep(-0.008,0.012,d);
                output=max(output,vec2f(fill*0.55+band(d,0.022), fill*0.25+band(d,0.01))*facet);
            }
            let floorl = exp(-abs(p.y-0.38)*7.0)*smoothstep(0.12,0.42,p.y)*t(2u)*0.35;
            return output*mix(0.5,1.4,t(0u))+vec2f(floorl, t(1u)*0.22+floorl);
        }
        case 13u: { // Glass Torus — tilted glass ring with faceted rim
            let q = p*vec2f(1.0, mix(1.05, 1.55, t(8u)));
            let radius = mix(0.16, 0.4, t(5u));
            let thick = mix(0.028, 0.13, t(6u));
            let d = abs(length(q)-radius)-thick*0.38;
            let twist = 0.3+0.7*pow(0.5+0.5*cos(atan2(q.y,q.x)*max(2.0,t(7u))+time), 2.0);
            let fill = 1.0-smoothstep(-0.008, 0.014, d);
            return vec2f(fill*0.45+band(d,thick)*twist, fill*0.2+band(d,0.012))*mix(0.5,1.4,t(0u));
        }
        case 14u: { // Hanging Blades — perspective row of tall blades catching a chase
            var output = vec2f(0);
            let blades = clamp(round(t(0u)), 3.0, 14.0);
            for (var n=0u; n<14u; n++) {
                if f32(n) >= blades { break; }
                let i=f32(n);
                let z = mix(0.42, 1.45, i/max(1.0, blades-1.0));
                let chase = sin(time*(0.7+t(3u))+i)*t(1u)*0.05;
                let v = p-vec2f((i-(blades-1.0)*0.5)*mix(0.07,0.16,t(1u))/z, -0.04/z+chase);
                let size=vec2f(mix(0.01,0.028,t(2u))/z, mix(0.16,0.48,t(4u))/z);
                let d=box_distance(v,size,0.006/z);
                let stripe = 0.5+0.5*cos(v.y*14.0*z)*t(2u);
                output=max(output,emitter(d,0.9)*stripe*(1.1-z*0.25));
            }
            return output;
        }
        case 15u: { // Light Slab — solid panel with floor reflection
            let cy = mix(-0.28, 0.18, t(3u)+1.0);
            let half = vec2f(mix(0.06, 0.28, t(0u)), mix(0.08, 0.32, t(1u)));
            let d=box_distance(p-vec2f(0.0, cy), half, 0.012);
            let fill=1.0-smoothstep(-0.01,0.006,d);
            let glow=exp(-max(d,0.0)*mix(8.0, 28.0, 1.0-t(2u)))*t(2u);
            var refl = 0.0;
            if p.y < -0.35 {
                let ry = -0.7-p.y;
                let d2=box_distance(vec2f(p.x, ry)-vec2f(0.0, cy), half, 0.012);
                refl = exp(-max(d2,0.0)*10.0)*exp((-0.35-p.y)*3.0)*t(4u);
            }
            return vec2f(fill*0.8+glow+refl, fill*t(4u)+glow+refl);
        }
        case 16u: { // Floating Ellipse — filled disc + outer pool
            let c = vec2f(0.0, mix(-0.25, 0.28, t(2u)*0.5+0.5));
            let q = (p-c)/vec2f(mix(0.18, 0.72, t(0u)), mix(0.06, 0.42, t(1u)));
            let d = (length(q)-1.0)*mix(0.06, 0.42, t(1u));
            let disc = 1.0-smoothstep(-0.006, 0.006, d);
            let pool = exp(-max(d,0.0)*mix(6.0, 22.0, 1.0-t(3u)))*t(3u);
            return vec2f(disc*0.92+pool*(1.0-disc), disc*t(3u)+pool);
        }
        case 17u: { // Bottom Glow · Height / Softness / Breathe / Sway / Edge
            let edge = u32(clamp(t(4u)+0.5, 0.0, 3.0));
            let sway = sin(time*1.35+seed)*t(3u)*0.05;
            var dist = 1.0-uv.y;
            if edge==0u { dist = uv.y; }
            if edge==1u { dist = 1.0-uv.x; }
            if edge==3u { dist = uv.x; }
            dist = max(0.0, dist+sway);
            let reach = mix(0.05, 0.62, t(0u));
            let soft = mix(0.018, 0.16, t(1u));
            let breathe = 0.82+0.18*sin(time*2.1)*t(2u);
            let wash = exp(-dist/max(0.02, reach));
            let lip = exp(-pow(dist/max(0.008, soft), 2.0));
            return vec2f(wash*0.9+lip*0.35, lip+wash*0.45)*breathe;
        }
        case 18u: { // Linear Drift
            let dir = rotate2(q, t(0u));
            let ramp=smoothstep(-t(1u), t(1u), dir.x+0.24*drift.x*t(2u));
            let contrast = mix(0.6, 1.6, t(4u));
            return vec2f(pow(ramp,contrast)*0.82, pow(ramp,contrast+0.6)*0.60);
        }
        case 19u: { // Edge Light · Thickness / Softness / Pulse / Fog
            let pulse = 0.78+0.22*sin(time*2.4)*t(2u);
            let half = vec2f(max(aspect,1.0), max(1.0,1.0/aspect))*0.49;
            let thick = mix(0.03, 0.26, t(0u));
            let fog = mist(p*3.2+drift*0.2+seed)*t(3u);
            return frame_glow(p, half, mix(0.03, 0.14, t(1u)), thick, t(1u))*pulse + vec2f(fog*0.12, fog*0.08);
        }
        case 20u: { // Mesh · inverse-distance color points
            let n = clamp(t(0u), 3.0, 8.0);
            let soft = max(0.05, t(1u));
            var num = 0.0;
            var den = 0.0;
            for (var i=0u; i<8u; i++) {
                if f32(i) >= n { break; }
                let k = f32(i);
                let c = vec2f(sin(k*2.3+seed)*0.62, cos(k*1.9+seed*1.3)*0.38)
                    + vec2f(cos(time+k*1.7), sin(time+k*2.2))*0.12*t(1u);
                let d2 = dot(p-c, p-c);
                let w = 1.0/(d2*d2*4.0+soft*0.05+0.001);
                num += w*fract(k*0.618+0.15);
                den += w;
            }
            let mesh = num/max(den, 0.001);
            return vec2f(clamp(mesh,0.0,1.0), clamp(mesh*mesh,0.0,1.0));
        }
        case 21u: { // Bloom Bars — discrete columns, not a sine grating
            let bars = max(2.0, t(0u));
            let x = p.x*bars*0.55;
            let id = floor(x+0.5);
            let f = x-id;
            let br = exp(-f*f/mix(0.012, 0.14, t(1u)));
            let pulse = 0.62+0.38*sin(time*2.0+id*1.7)*t(2u);
            let fall = mix(0.55, 1.0, smoothstep(-0.55, 0.15, p.y));
            return vec2f(br*pulse*fall, br*pulse)*exp(-abs(p.y)*0.35);
        }
        case 22u: { // Halo — filled disc with interior bands
            let radius = mix(0.22, 0.52, t(0u)/1.2);
            let inside = smoothstep(radius*(1.0+t(3u)*0.25), radius*(1.0-t(3u)*0.25), r);
            let q = rotate2(p, t(2u));
            let st = pow(0.5+0.5*sin(q.y/max(0.08,radius)*t(1u)*3.14159+time), 2.4);
            let sh = sqrt(max(0.0, 1.0-r*r/max(0.04, radius*radius)));
            return vec2f(inside*(0.22+0.78*st)*sh, inside*st*sh);
        }
        case 23u: { // Halo Ring
            let radius = mix(0.18, 0.48, t(0u)/1.2);
            let thick = max(0.012, t(1u));
            let d = r-radius;
            let sw = 0.55+0.45*pow(0.5+0.5*cos(a-time), 3.0);
            return vec2f(exp(-d*d/(thick*thick))*sw, exp(-abs(d)*4.0)+t(2u)*exp(-r/max(0.08,radius))*0.4);
        }
        case 24u: { // Eclipse
            let radius = t(0u)*0.42;
            let d = r-radius;
            let corona = t(1u)*band(d, 0.12)*step(0.0,d);
            let diamond = t(2u)*pow(0.5+0.5*cos(a*4.0), 6.0)*exp(-3.0*r);
            return vec2f(band(d,0.10)*step(0.0,d)+corona, band(d,0.008)+diamond);
        }
        case 25u: { // Cross of Rays — bright cross opening with shafts through haze
            let v=p+vec2f(0.0,0.03);
            let d=min(box_distance(v,vec2f(mix(0.012,0.055,t(1u)), mix(0.2,0.44,t(0u))),0.004),
                      box_distance(v+vec2f(0.0, mix(-0.02,0.1,t(2u))),vec2f(mix(0.12,0.3,t(0u)), mix(0.012,0.04,t(1u))),0.004));
            let fill=1.0-smoothstep(-0.005,0.008,d);
            let glow=exp(-max(d,0.0)*mix(7.0, 26.0, 1.0-t(2u)));
            let shafts=radial_rays(v, mix(6.0, 22.0, t(3u)), 0.42, 0.72, seed, drift);
            let haze=mist(p*3.0+seed)*t(2u)*0.25;
            return vec2f(fill*0.92+glow+haze, fill+glow)+shafts*(0.45+0.55*(1.0-fill));
        }
        case 26u: { // Silhouette Cross — dark cross blocking a radiant field
            let v=p+vec2f(0.0,0.03);
            let d=min(box_distance(v,vec2f(mix(0.018,0.045,t(1u)),0.34),0.004),
                      box_distance(v+vec2f(0.0,0.09),vec2f(0.19, mix(0.016,0.032,t(1u))),0.004));
            let solid=1.0-smoothstep(-0.006,0.006,d);
            let rim=exp(-abs(d)*22.0);
            let field=radial_rays(v, mix(8.0, 24.0, t(3u)), 0.38, 0.65, seed, drift);
            return (field+vec2f(rim*0.5, rim))*(1.0-solid*0.92)+vec2f(0.0, rim*0.2);
        }
        case 27u: { // Glass Cross — thick glass latin cross with faceted rim
            let v=p+vec2f(0.0,0.04);
            let d=min(box_distance(v,vec2f(mix(0.02,0.07,t(6u)), mix(0.18,0.4,t(5u))), mix(0.0,0.03,t(10u))),
                      box_distance(v+vec2f(0.0, mix(0.04,0.12,t(5u)*0.4)),vec2f(mix(0.12,0.28,t(5u)), mix(0.016,0.05,t(6u))), mix(0.0,0.02,t(10u))));
            let fill=1.0-smoothstep(-0.006,0.012,d);
            let facet=0.35+0.65*pow(abs(sin(v.x*14.0+v.y*9.0+drift.x)),2.0);
            return vec2f(fill*0.55*facet+band(d,0.024)*t(2u), fill*0.25+band(d,0.01))*mix(0.5,1.4,t(0u));
        }
        case 28u: { // Curtain Streaks · Cross — hanging strands with a cross in the wash
            let curtain=pow(0.5+0.5*cos(p.x*mix(18.0,90.0,t(0u))+sin(p.y*3.0)*2.0), mix(3.0,12.0,t(1u)));
            let fall=smoothstep(-0.55,0.35,p.y);
            let v=p+vec2f(0.0,0.03);
            let d=min(box_distance(v,vec2f(0.022, mix(0.16,0.34,t(3u))),0.004),
                      box_distance(v+vec2f(0.0,0.08),vec2f(mix(0.1,0.22,t(3u)),0.02),0.004));
            let shape=(1.0-smoothstep(-0.005,0.008,d))*t(4u);
            return vec2f(curtain*fall*0.7+shape, curtain*fall+shape);
        }
        case 29u: { // Light Threads — hanging vertical fibers at several depths
            let n = mix(10.0, 46.0, t(0u));
            var body = 0.0;
            for (var layer=0u; layer<4u; layer++) {
                let z = f32(layer);
                let dens = n*(0.55+0.18*z);
                let x = p.x*dens + sin(time*(0.6+z*0.25)+z)*t(1u)*0.08 + z*0.07;
                let id = floor(x);
                let f = fract(x)-0.5;
                let h = hash(vec2f(id, z+seed));
                let breath = 0.45+0.55*pow(0.5+0.5*sin(time*2.2+h*20.0), 2.0)*t(1u);
                let thread = exp(-f*f*mix(28.0, 140.0, h))*breath*(0.35+0.65*h);
                let glint = exp(-f*f*400.0)*hash(vec2f(id, floor(p.y*40.0+time*8.0)))*t(1u);
                body += (thread+glint)*smoothstep(-0.62, 0.2, p.y);
            }
            return vec2f(body*0.55, body);
        }
        case 30u: { // Snow Glint — low winter sun on a field of flashing crystals
            let ground = smoothstep(-0.2, 0.55, p.y);
            let sun = t(1u)*exp(-p.x*p.x*2.8)*exp(-abs(p.y+0.02)*3.5);
            let glints = glitter_field(p+vec2f(time*0.03, 0.0), t(0u)*22.0, 0.35, 0.9, time, seed);
            return vec2f(sun*0.5+glints.x*ground, sun+glints.y*ground);
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
        case 35u: { // Burst Fans — sprays from below the frame
            let origin = vec2f(0.0, mix(0.38, 0.72, t(1u)));
            let q = p-origin;
            let ang = atan2(q.x, -q.y);
            let u = ang*t(0u)*0.12;
            let id = floor(u);
            let f = fract(u)-0.5;
            let d = length(q);
            let head = fract(hash(vec2f(id, seed))+time*0.15);
            let bandv = smoothstep(head-0.25, head, d)*smoothstep(head+0.05, head, d);
            let ray = exp(-f*f*mix(20.0, 80.0, t(3u)))*step(0.0, -q.y+0.2);
            return vec2f(ray*bandv, ray*bandv)*(0.6+t(4u))+radial_rays(q, t(0u)*0.08, 0.9, 0.4, seed, drift)*0.25;
        }
        case 36u: { // Wave Slats — stacked bars riding a travelling wave
            let slats = max(4.0, t(0u));
            let v = rotate2(p, mix(-28.0, 28.0, t(3u)*0.5+0.5));
            let y = v.y + 0.1*sin(v.x*max(0.5,t(1u))+drift.y)*t(4u);
            let g = pow(0.5+0.5*cos(y*slats), mix(3.0, 14.0, t(2u)));
            return vec2f(g, g*0.78)*smoothstep(0.85, 0.15, abs(v.x));
        }
        case 37u: { // Arch Rows — concentric LED arches made of short blocks
            let rows = max(4.0, t(0u));
            let v=vec2f(p.x, min(p.y-0.18, 0.0));
            let radius=length(v);
            let ring=fract(radius*rows*0.55+time*t(3u)*0.15);
            let line=band(ring-0.5, mix(0.03,0.12,t(1u)));
            let segs=max(4.0, mix(6.0, 28.0, t(2u)));
            let ang=atan2(v.y,v.x);
            let block=1.0-smoothstep(mix(0.12,0.42,t(2u)), 0.5, abs(fract(ang*segs)-0.5));
            return vec2f(line*block, line*block)*smoothstep(0.08, 0.16, radius)*t(4u);
        }
        case 38u: { // Block Wall — brick LED wall with chase rise
            let cols = max(6.0, t(0u));
            let rows = max(3.0, t(1u));
            let brick = p*vec2f(cols, rows)+vec2f(select(0.0, 0.5, fract(floor(p.y*rows)*0.5+0.25)>0.5), 0.0);
            let cell = floor(brick);
            let f = fract(brick)-0.5;
            let rnd = hash(cell+seed);
            let rise = smoothstep(0.0, 1.0, fract(time*0.25*t(2u)+rnd));
            let mask = 1.0-smoothstep(0.38-t(4u)*0.1, 0.48, max(abs(f.x), abs(f.y)));
            let lit = mix(t(3u)*0.3, 1.0, rise*rnd);
            return vec2f(mask*lit, mask*lit*rnd);
        }
        case 39u: { // Panel Mosaic — uneven LED columns lighting in groups
            let cols = max(3.0, t(0u));
            let x = (p.x+0.5)*cols;
            let id = floor(x);
            let h = hash(vec2f(id, seed));
            let rows = mix(5.0, 18.0, h*0.7+t(3u)*0.3);
            let gy = (p.y+0.5)*rows;
            let f = vec2f(fract(x)-0.5, fract(gy)-0.5);
            let gap = mix(0.06, 0.3, t(1u));
            let mask = 1.0-smoothstep(0.4-gap*0.25, 0.48, max(abs(f.x), abs(f.y)));
            let group = step(0.32, hash(vec2f(id, floor(gy*0.3)+seed)));
            let flicker = mix(1.0, 0.35+0.65*step(0.4, 0.5+0.5*sin(time*5.0+h*12.0)), t(2u));
            let body = mask*mix(0.2, 1.0, group)*flicker;
            return vec2f(body, body)*mix(0.5, 1.3, t(4u));
        }
        case 40u: { // Silk Light — folding ribbons filling the frame
            let folds = mix(1.4, 7.0, t(7u));
            let warp = 0.22*sin(p.x*folds+drift.y+time*0.35)*t(6u)+0.07*sin(p.x*2.4+p.y*1.2+time);
            let y = p.y+warp;
            let layers = pow(0.5+0.5*cos(y*mix(3.5, 16.0, t(1u))), mix(1.8, 7.0, t(1u)));
            let shade = 0.55+0.45*smoothstep(-0.5, 0.45, p.y);
            return vec2f(layers*shade, layers*layers)*mix(0.45, 1.35, t(0u));
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
        case 43u: { // Volume Rays — shafts falling from above through drifting fog
            let origin = vec2f(mix(-0.28, 0.28, t(3u)*0.5+0.5), -0.78);
            let qv = p-origin;
            let ang = atan2(qv.x, -qv.y);
            let n = mix(3.0, 18.0, t(2u));
            let f = fract(ang*n*0.55)-0.5;
            let shaft = exp(-f*f*mix(18.0, 80.0, t(1u)))*exp(-length(qv)*0.45);
            let fog = mist(p*2.8+drift+seed)*t(1u);
            return vec2f(shaft*0.7+fog*0.35, shaft+fog*0.2)*mix(0.4,1.45,t(0u));
        }
        case 44u: { // Ramp Squares — nested rounded square rims, each turning
            var light = vec2f(0);
            let n = mix(3.0, 8.0, t(5u));
            for (var i=0u; i<8u; i++) {
                if f32(i) >= n { break; }
                let index = f32(i);
                let size = mix(0.1, 0.44, t(5u))*pow(0.7, index);
                let v = rotate2(p, time*(8.0+index*6.0)*t(3u)+index*18.0*t(7u));
                let d = box_distance(v, vec2f(size), mix(0.0, size*0.4, t(6u)));
                light = max(light, vec2f(band(d, mix(0.01,0.04,t(2u))), band(d,0.008))*(1.0-index*0.08));
            }
            let core = exp(-r*r*16.0)*t(2u);
            return (light+vec2f(core, core))*mix(0.5, 1.45, t(0u))*mix(0.7, 1.25, t(1u));
        }
        case 45u: { // Glass Ripple — concentric glass rings from centre, no hard clip
            let wave = 0.04*sin(a*mix(1.0,10.0,t(5u))+drift.y)+0.012*cos(a*7.0);
            let optical = pow(0.5+0.5*cos(mix(10.0, 64.0, t(6u))*(r+wave)+time*t(3u)*4.0), mix(2.2, 7.5, t(7u)));
            let falloff = exp(-r*1.15);
            return vec2f(optical*falloff, optical*falloff*(0.5+t(2u)))*mix(0.5,1.4,t(0u))*mix(0.7,1.3,t(1u));
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
        case 48u: { // Point Wave — discrete dots riding a sine
            let dens = max(8.0, t(0u));
            let wave = 0.14*sin(p.x*t(2u)+drift.x)*t(1u);
            let gx = p.x*dens*0.28;
            let gy = (p.y-wave)*mix(10.0, 28.0, clamp(t(3u)/1.8,0.0,1.0));
            let f = vec2f(fract(gx)-0.5, fract(gy)-0.5);
            let mask = 1.0-smoothstep(mix(0.06,0.22,clamp(t(3u)/1.8,0.0,1.0)), 0.38, length(f));
            return vec2f(mask*0.72, mask);
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
        case 63u: { // Failing Ceiling — face-on panel grid, many dead, some stuttering
            let cols = mix(5.0, 14.0, t(5u));
            let rows = mix(4.0, 10.0, t(5u));
            let g = grid_cells(p, cols, rows, 0.14, seed, time*t(3u));
            let cell = floor(p*vec2f(cols, rows)+vec2f(cols, rows)*0.5);
            let rnd = hash(cell+seed);
            let stutter = select(0.06, select(step(0.35, 0.5+0.5*sin(time*14.0+rnd*40.0)), 1.0, rnd>0.45), rnd>0.22);
            return g*vec2f(t(0u), t(2u))*stutter;
        }
        case 64u: { // Office Ceiling — even lit panel grid
            return grid_cells(p, 10.0, 6.0, 0.1, seed, 0.0)*vec2f(0.45+t(0u), 0.3+t(1u));
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
        case 68u: { // Hidden Light · Panel / Spill / Roundness
            let panel = mix(0.42, 0.94, t(0u));
            let half = vec2f(max(aspect,1.0), max(1.0,1.0/aspect))*0.5*panel;
            let roundness = mix(0.02, min(half.x, half.y)*0.9, t(2u));
            let spill = mix(0.03, 0.22, t(1u));
            return frame_glow(p, half, roundness, spill, t(2u));
        }
        case 69u: { // Sky Opening — filled rounded window of light + ceiling wash
            let size = mix(0.12, 0.48, t(0u));
            let d = box_distance(p-vec2f(0.0, 0.02), vec2f(size*1.05, size*0.78), mix(0.02, size*0.85, t(1u)));
            let fill = 1.0-smoothstep(-0.004, 0.01, d);
            let spill = exp(-max(d,0.0)*mix(7.0, 26.0, 1.0-t(2u)));
            let ceil = t(2u)*exp(-max(0.0, 0.52-p.y)*9.0)*0.45;
            return vec2f(fill*0.95+spill*(1.0-fill)+ceil, fill+spill);
        }
        case 70u: { // Arch Opening — filled door-arches standing on the floor
            var light = vec2f(0);
            let n = max(1.0, t(0u));
            let w = mix(0.08, 0.28, t(2u));
            let h = mix(0.2, 0.52, t(1u));
            let floor_y = 0.46;
            for (var i=0u; i<5u; i++) {
                if f32(i) >= n { break; }
                let x = (f32(i)-(n-1.0)*0.5)*w*2.35;
                let lx = p.x-x;
                let ly = floor_y-p.y;
                let d = max(length(vec2f(lx, min(ly-(h-w), 0.0)))-w, -ly);
                let fill = (1.0-smoothstep(-0.004, 0.01, d))*step(-0.02, ly);
                let spill = exp(-max(d,0.0)*14.0)*t(3u);
                light = max(light, vec2f(fill*0.95+spill, fill+spill));
            }
            return light;
        }
        case 71u: { // Oculus — filled circular window with dome shading
            let radius = mix(0.14, 0.4, t(0u));
            let c = vec2f(0.0, 0.12);
            let v = p-c;
            let d = length(v)-radius;
            let disc = 1.0-smoothstep(-0.006,0.01,d);
            let dome = mix(1.0, 0.35, t(1u)*clamp((v.y+radius)/(2.0*radius),0.0,1.0));
            let rim = band(d, 0.02)*t(2u);
            return vec2f(disc*dome+rim*0.4, disc*0.55+rim);
        }
        case 72u: { // Portal — glowing rounded doorway, dark inside
            let d=box_distance(p-vec2f(0.0,0.04),vec2f(mix(0.1,0.28,t(1u)), mix(0.16,0.38,t(0u))), mix(0.02,0.16,t(2u)));
            let fill=1.0-smoothstep(-0.01,0.008,d);
            let rim=exp(-abs(d)*mix(12.0, 40.0, 1.0-t(3u)));
            return vec2f(rim*(1.0-fill*0.7)+fill*0.08, rim+fill*t(3u)*0.2);
        }
        case 73u: { // Pillar — tall vertical blade of light
            let v = rotate2(p, t(1u));
            let core = exp(-abs(v.x)/max(0.012, t(0u)*0.18));
            let fall = smoothstep(-0.62, 0.15, p.y)*smoothstep(0.55, -0.05, p.y);
            return vec2f(core*fall, core*core*fall);
        }
        case 74u: { // Water Curtain — falling streams, backlit, mist at the foot
            let n = mix(12.0, 70.0, t(5u));
            let x = p.x*n + sin(p.y*8.0+time*2.0)*0.35;
            let streams = pow(0.5+0.5*cos(x), mix(4.0, 16.0, t(1u)));
            let fall = 0.55+0.45*smoothstep(-0.5, 0.4, p.y);
            let mistb = mist(vec2f(p.x*3.0, p.y*2.0+time)+seed)*smoothstep(0.05, 0.45, p.y)*t(7u);
            return vec2f(streams*fall*t(0u)+mistb*0.4, streams*t(1u)+mistb);
        }
        case 75u: { // Event Horizon — dark core, warped disk wrapping over and under
            let radius = mix(0.14, 0.38, t(5u));
            let hole = 1.0-smoothstep(radius-0.01, radius+0.008, r);
            let ell = length(p/vec2f(1.0, mix(0.16, 0.42, t(6u))));
            let disk = band(ell-radius*1.15, mix(0.035, 0.12, t(7u)))*(1.0-hole*0.88);
            let rim = band(r-radius, 0.018)*(1.0-hole);
            let stars = glitter_field(p, 14.0, 0.22, 0.85, time, seed)*(1.0-hole);
            return vec2f(disk*0.75+rim*0.4+stars.x, disk+rim+stars.y)*mix(0.5,1.4,t(0u));
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
        case 82u: { // Gradient Sweep — soft directional wash
            let v = rotate2(q, mix(-55.0, 55.0, t(0u))+drift.x*12.0);
            let spread = max(0.15, t(2u)*0.55);
            let ramp = smoothstep(-spread, spread, v.y);
            let body = pow(ramp, mix(0.45, 2.4, t(1u)));
            return vec2f(body*0.9, body*body);
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
        case 89u: { // Threshold — lit floor plane meeting a back wall
            let horizon = t(2u);
            let floorv = smoothstep(horizon-0.02, horizon+0.35, p.y)*exp(-abs(p.y-horizon)*mix(1.2, 6.0, t(0u)));
            let wall = exp(-abs(p.y-horizon)*mix(2.0, 10.0, 1.0-t(1u)))*smoothstep(horizon, horizon-0.4, p.y);
            return vec2f(floorv*0.85+wall*0.45, floorv+wall*0.6);
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
