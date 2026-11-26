// A finish samples the current look through a surface. Sampling is stateless
// so preview, still export and any frame of a loop produce the same treatment.
fn finish_color(uv: vec2f, finish: u32) -> vec3f {
    let phase = settings.phase;
    let t = phase*6.283185307;
    let motion = vec2f(cos(t),sin(t))*settings.energy;
    let p = uv-0.5;
    let aspect = settings.composition;
    let fit = vec2f(max(1.0,aspect),max(1.0,1.0/aspect));
    let shape = p*fit;
    let surface = uv*fit;
    let cell = floor(surface*24.0);
    let grain = hash(floor(surface*290.0)+f32(settings.seed));
    let flute_axis = vec2f(cos(radians(finish_t(2u))), sin(radians(finish_t(2u))));
    let flutes = fract(dot(surface, flute_axis)*max(2.0, finish_t(0u)))-0.5;
    var sample_uv = uv;
    var mask = 1.0;
    var taps = 1u;
    var separation = vec2f(0);
    var delay = 0.0;
    var floor_reflection = false;
    switch finish {
        case 1u, 8u, 9u: {
            let reed = sin(flutes*6.2831853);
            var refraction = reed*finish_t(1u)*0.12;
            if finish==8u { refraction=reed*mix(0.004,0.04,finish_t(1u)); }
            if finish==9u { refraction=reed*mix(0.01,0.08,finish_t(1u))+sin(surface.x*231.0)*0.009; }
            sample_uv.x += refraction/fit.x;
            mask = 0.74+0.26*smoothstep(-0.3,0.3,reed);
        }
        case 3u: { // Prism Bars — columns that stretch and flip the look
            let bars = max(2.0, finish_t(0u));
            let x = uv.x*bars + finish_t(3u)*0.35;
            let id = floor(x);
            let f = fract(x);
            let h = hash(vec2f(id, 3.1));
            var u = f;
            if h < finish_t(2u) { u = 1.0-u; }
            let stretch = mix(0.45, 2.1, finish_t(1u));
            u = clamp(0.5+(u-0.5)*stretch, 0.0, 1.0);
            sample_uv.x = (id+u)/bars;
            mask = mix(1.0, 0.62+0.38*(1.0-abs(f-0.5)*2.0), finish_t(4u));
        }
        case 2u, 39u, 41u, 42u: {
            taps = 3u;
            if finish==2u { separation = vec2f(0.008,0.004)*mix(1.0, 8.0, finish_t(0u))*finish_t(1u); }
            if finish==39u { separation = vec2f(0.019,0.013)*finish_t(0u)*smoothstep(0.035,0.45,abs(p.y)); }
            if finish==41u { separation = vec2f(0.092,0.019)*finish_t(0u)*(0.5+motion.y*0.31); delay=0.027*finish_t(1u); }
            if finish==42u { separation = vec2f(0.034,0.016)*finish_t(0u); delay=0.12*finish_t(1u); }
        }
        case 4u, 5u, 7u: {
            var grid = surface*11.0;
            if finish==4u { grid=vec2f(uv.x*4.0,uv.y); }
            if finish==7u { grid=vec2f(surface.x*4.6,uv.y); }
            let f = fract(grid)-0.5;
            let offset = hash(floor(grid)+4.2)-0.5;
            sample_uv += vec2f(offset*0.09,f.x*0.011)/fit;
            mask = 1.0-smoothstep(0.42,0.49,max(abs(f.x),abs(f.y)))*0.86;
            if finish==7u {
                let arch = max(abs(f.x)-0.42,length(vec2f(f.x,min(f.y+0.16,0.0)))-0.42);
                let lead = abs(sin(f.y*61.0+sin(f.x*24.0)*0.84)*cos(f.x*33.0+f.y*8.0));
                mask = (1.0-smoothstep(-0.026,0.0,arch))*mix(0.27,1.0,smoothstep(0.04,0.21,lead));
            }
        }
        case 6u: {
            let dir = radians(finish_t(2u));
            let wave = vec2f(cos(dir), sin(dir))*finish_t(0u);
            sample_uv += vec2f(sin(dot(surface,wave)*2.0+motion.x),cos(dot(surface,wave.yx)*2.0+motion.y))*0.08*finish_t(1u)/fit;
        }
        case 29u: { // Iris — oval window, softness and surround fill
            let size = mix(0.18, 0.72, finish_t(0u)/1.5);
            let oval = length(shape/vec2f(mix(1.0, 1.8, finish_t(2u)), 1.0));
            let soft = mix(0.01, 0.22, finish_t(1u));
            let hole = 1.0-smoothstep(size, size+soft, oval);
            let angle = radians(finish_t(4u));
            let shade = clamp(0.5+dot(p,vec2f(cos(angle),sin(angle))),0.0,1.0);
            mask = mix(hole, 1.0, finish_t(3u)*0.7*shade);
        }
        case 30u: { // Arch Window — one or more door-arches
            let n = max(1.0, finish_t(4u));
            let w = mix(0.08, 0.38, finish_t(0u)/1.2);
            let h = mix(0.12, 0.48, finish_t(1u));
            var hole = 0.0;
            for (var i=0u; i<7u; i++) {
                if f32(i) >= n { break; }
                let x = (f32(i)-(n-1.0)*0.5)*w*2.3;
                let q = shape-vec2f(x, 0.08);
                let arch = max(length(vec2f(q.x, min(q.y+h*0.15, 0.0)))-w, q.y-h);
                let opening = 1.0-smoothstep(-0.008, 0.01, arch);
                let spill = band(arch,0.085)*finish_t(2u)*0.35;
                let rim = band(arch,0.008)*finish_t(3u)*0.55;
                hole = max(hole, max(opening,spill+rim));
            }
            mask = hole;
        }
        case 31u: { // Slab Window — rounded rectangle opening
            let half = vec2f(mix(0.08, 0.48, finish_t(0u)/1.2), mix(0.1, 0.48, finish_t(1u)));
            let d = box_distance(shape, half, 0.02);
            mask = 1.0-smoothstep(-0.008, mix(0.004, 0.08, finish_t(2u)), d);
            floor_reflection = uv.y > mix(0.62, 0.88, 0.5-finish_t(3u)*0.5) && finish_t(4u) > 0.05;
            if floor_reflection {
                sample_uv.y = 1.46-uv.y;
                mask = mix(mask, finish_t(4u)*0.45*(1.0-smoothstep(0.7, 1.0, uv.y)), 1.0);
            }
        }
        case 32u: { // Wing Fade — darken sides and/or top and bottom
            let w = mix(0.08, 0.55, finish_t(0u));
            let sides = smoothstep(w, w+0.18, abs(p.x));
            let tb = smoothstep(0.32, 0.52, abs(p.y));
            mask = 1.0 - sides*finish_t(1u)*0.92 - tb*finish_t(2u)*0.85;
        }
        case 33u: { // Spotlight — wandering pool of light
            let wander = vec2f(sin(t), cos(t))*0.18*finish_t(2u);
            let size = mix(0.8, 6.0, 1.0-finish_t(0u)/2.0);
            mask = mix(finish_t(1u)*0.15, 1.0, exp(-dot(shape-wander, shape-wander)*size));
        }
        case 34u: { // Lyric Fade — gradient band at bottom or top
            let h = mix(0.08, 0.55, finish_t(0u));
            var dist = uv.y;
            if finish_t(2u) < 0.5 { dist = 1.0-uv.y; }
            mask = 1.0-finish_t(1u)*exp(-dist/max(0.04, h));
        }
        case 35u: { // Mirror — fold the look
            let mode = u32(clamp(finish_t(0u)+0.5, 0.0, 2.0));
            let c = 0.5+finish_t(1u)*0.35;
            if mode==0u { sample_uv.x = c+abs(uv.x-c); }
            else if mode==1u { sample_uv.y = c+abs(uv.y-c); }
            else {
                let seg = max(3.0, finish_t(2u));
                let a = atan2(p.y, p.x);
                let r = length(p);
                let u = abs(fract(a*seg/6.2831853+0.5)-0.5)*2.0;
                sample_uv = 0.5+vec2f(cos(u*3.14159), sin(u*3.14159))*r;
            }
        }
        case 36u: { // Mirror Tunnel — recursive frames
            let depth_n = clamp(finish_t(0u), 1.0, 8.0);
            let travel=sin(t*round(finish_t(2u)))*0.15;
            let frame=max(abs(p.x),abs(p.y))*exp2(travel);
            let depth=clamp(floor(-log2(max(frame,0.018)))-1.0,0.0,depth_n-1.0);
            let rot = finish_t(3u)*0.35*depth;
            let q = rotate2(p, rot*57.3);
            sample_uv=0.5+q*exp2(depth+travel);
            mask=mix(1.0, 1.0-depth/depth_n, finish_t(4u))*mix(1.0, 0.75+0.25*finish_t(1u), 1.0);
        }
        case 37u: { // Reflection — floor bounce
            let floor_h = mix(0.55, 0.92, finish_t(0u));
            floor_reflection=uv.y>floor_h;
            if floor_reflection {
                sample_uv.y=floor_h*2.0-uv.y;
                sample_uv.x+=0.02*sin(uv.y*160.0+motion.x)*finish_t(2u);
                mask=finish_t(1u)*0.55*(1.0-smoothstep(floor_h, 1.0, uv.y));
            }
        }
        case 21u: {
            sample_uv=0.5+p*(1.0+finish_t(2u)*dot(p,p)*0.35);
        }
        case 38u: { sample_uv.y += sin(surface.x*17.0+motion.x*1.8)*0.095*uv.y; }
        case 25u, 40u: {
            taps=3u;
            separation=vec2f(0.033,0.009)*select(1.0,0.6+motion.x*0.32,finish==40u);
        }
        case 43u: {
            let row=floor(uv.y*27.0);
            sample_uv.x=0.5+p.x*(0.57+0.66*hash(vec2f(row,3.0)));
            sample_uv.y=(row+0.5)/27.0;
        }
        case 44u: {
            let grid=vec2f(33.0,18.0);
            let column=floor(uv.x*grid.x);
            sample_uv.y+=0.037*(hash(vec2f(column,1.0))-0.5);
            sample_uv=(floor(sample_uv*grid)+0.5)/grid;
        }
        case 45u: {
            let column=floor(uv.x*57.0);
            sample_uv.y=0.5+p.y*(0.43+0.76*hash(vec2f(column,2.0)))+0.05*motion.y;
            sample_uv.y=floor(sample_uv.y*39.0)/39.0;
        }
        case 46u: {
            let block=floor(uv*vec2f(7.0,13.0));
            let key=hash(block+6.8);
            let shift=smoothstep(0.55,0.85,key)*pow(0.5+0.5*sin(t+key*22.0),4.0);
            sample_uv.x += shift*(0.24-0.42*key);
            mask=1.0-shift*0.43;
        }
        default: {}
    }

    var color = vec3f(0);
    for (var i=0u; i<taps; i++) {
        let offset = f32(i)-f32(taps-1u)*0.5;
        let rgb = look_color(clamp(sample_uv+separation*offset,vec2f(0),vec2f(1)),phase+delay*offset);
        if finish==25u || finish==40u {
            let component = vec3f(select(0.0,1.0,i==0u),select(0.0,1.0,i==1u),select(0.0,1.0,i==2u));
            color += rgb*component;
        } else {
            color += rgb/f32(taps);
        }
    }

    let background = settings.colors[0].rgb;
    let level = clamp(dot(max(color-background,vec3f(0)),vec3f(0.25,0.63,0.12))*2.6,0.0,1.0);
    switch finish {
        case 2u: {
            color += (grain-0.5)*mix(0.02, 0.12, finish_t(1u)/4.0)*level;
            let edge = min(min(uv.x, 1.0-uv.x), min(uv.y, 1.0-uv.y));
            color += finish_t(2u)*exp(-edge*14.0)*0.22*level;
        }
        case 10u: { // Halftone
            let ang = radians(finish_t(1u));
            let q = vec2f(surface.x*cos(ang)-surface.y*sin(ang), surface.x*sin(ang)+surface.y*cos(ang));
            let scale = mix(8.0, 48.0, (finish_t(0u)-3.0)/21.0);
            let d = length(fract(q*scale)-0.5);
            let fill = mix(0.12, 0.62, clamp(level*finish_t(2u), 0.0, 1.0));
            mask *= 1.0-smoothstep(fill, fill+0.08, d);
        }
        case 11u: { // Tiles
            let n = max(6.0, finish_t(0u));
            let grid = surface*n;
            let local = abs(fract(grid)-0.5);
            let gapw = mix(0.02, 0.22, finish_t(1u));
            let gap = smoothstep(0.5-gapw, 0.5, max(local.x, local.y));
            let vary = (hash(floor(grid))-0.5)*finish_t(2u)*0.25;
            mask *= 1.0-gap*0.85;
            color *= 1.0+vary;
        }
        case 18u: { // Blueprint Grid
            let n = max(2.0, finish_t(0u));
            let grid = surface*n;
            let local = abs(fract(grid)-0.5);
            let line = 1.0-smoothstep(0.0, mix(0.02, 0.12, finish_t(2u)), min(local.x, local.y));
            mask *= mix(1.0, 0.72+line*0.4, finish_t(1u));
            color += line*0.05*settings.colors[2].rgb*finish_t(1u);
        }
        case 19u: { // LED Wall — dots in panels with seams
            let tall = max(10.0, finish_t(0u));
            let grid = uv*vec2f(tall*aspect, tall);
            let f = fract(grid)-0.5;
            let dotsz = mix(0.08, 0.42, finish_t(1u));
            let dots = 1.0-smoothstep(dotsz, dotsz+0.08, length(f));
            let panels = max(2.0, finish_t(2u));
            let pg = fract(uv*vec2f(panels*aspect, panels));
            let seam = min(min(pg.x, pg.y), min(1.0-pg.x, 1.0-pg.y));
            mask *= dots*(1.0-finish_t(3u)*(1.0-smoothstep(0.0, 0.04, seam)));
            color += step(1.0-finish_t(4u)*0.15, hash(floor(grid)+f32(settings.seed)))*0.35*dots;
        }
        case 12u: {
            mask*=1.0-abs(sin(surface.y*mix(20.0, 200.0, finish_t(0u)/200.0)*3.1415927))*mix(0.08, 0.4, finish_t(2u));
        }
        case 20u: { // LED Slats
            let slats = max(4.0, finish_t(0u));
            let v = rotate2(p, finish_t(3u));
            let x = fract((v.x+0.5)*slats+round(finish_t(4u))*settings.phase);
            let gap = mix(0.02, 0.28, finish_t(1u));
            let pix = max(1.0, finish_t(2u));
            let rows = 1.0-smoothstep(0.18, 0.42, abs(fract((v.y+0.5)*pix)-0.5));
            mask *= (1.0-smoothstep(0.5-gap, 0.52, abs(x-0.5))) * mix(1.0, rows, min(1.0, pix/80.0));
        }
        case 13u: { mask*=0.48+0.52*smoothstep(0.1,0.7,fract((surface.x+surface.y)*mix(40.0, 200.0, finish_t(0u)))+level*0.61); }
        case 14u: { mask*=mix(1.0, 0.68+0.32*noise(vec2f(surface.x*4.0,surface.y*215.0)), finish_t(0u)); }
        case 15u: { mask*=mix(1.0, 0.76+0.24*abs(sin(surface.x*183.0)*cos(surface.y*183.0)), finish_t(0u)); }
        case 16u: { color+=(noise(surface*mix(40.0, 180.0, finish_t(1u))+motion*0.23)-0.5)*mix(0.04, 0.22, finish_t(0u))*level; }
        case 17u: { color+=pow(grain, mix(8.0, 22.0, finish_t(1u)))*level*mix(0.05, 0.35, finish_t(0u)); }
        case 21u: { // CRT Phosphor
            let lines = max(60.0, finish_t(0u));
            let triads=fract(surface.x*mix(24.0, 90.0, finish_t(1u))+vec3f(0,0.3333,0.6667));
            color*=mix(vec3f(1.0), 0.55+0.7*(1.0-smoothstep(vec3f(0.23),vec3f(0.48),abs(triads-0.5))), finish_t(1u));
            let roll = settings.phase*round(finish_t(3u));
            mask*=1.0-abs(sin((surface.y*lines-roll)*3.1415927))*mix(0.08, 0.45, finish_t(4u)*0.4+0.2);
            color += level*finish_t(4u)*0.12;
        }
        case 22u: { mask*=0.59+0.41*sin(surface.x*250.0+motion.y+sin(surface.y*12.0)*2.7); }
        case 23u: { color=mix(color,vec3f(0.23,0.16,0.55)+level*0.55,level*0.30); }
        case 24u: { color+=settings.colors[2].rgb*band(length(p+vec2f(0.49,0.18)+motion*0.04),0.18)*0.30; }
        case 26u: { color+=mist(shape*3.0+motion*0.34)*settings.colors[1].rgb*0.23; }
        case 27u: { color=mix(color,settings.colors[1].rgb,0.22+0.13*sin(p.y*5.0+motion.x)); }
        case 28u: { color+=settings.colors[2].rgb*band(p.x+0.46-motion.x*0.13,0.09)*0.34; }
        case 37u: { if floor_reflection { color*=0.8; } }
        default: {}
    }
    return mix(background,color,clamp(mask,0.0,1.0));
}
