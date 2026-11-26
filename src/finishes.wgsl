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
    let flutes = fract(surface.x*22.0)-0.5;
    var sample_uv = uv;
    var mask = 1.0;
    var taps = 1u;
    var separation = vec2f(0);
    var delay = 0.0;
    var floor_reflection = false;
    switch finish {
        case 1u, 3u, 8u, 9u: {
            let reed = sin(flutes*6.2831853);
            var refraction = reed*0.021;
            if finish==3u { refraction=flutes*0.17; }
            if finish==8u { refraction=reed*0.009; }
            if finish==9u { refraction=reed*0.025+sin(surface.x*231.0)*0.009; }
            sample_uv.x += refraction/fit.x;
            mask = 0.74+0.26*smoothstep(-0.3,0.3,reed);
        }
        case 2u, 39u, 41u, 42u: {
            taps = 3u;
            if finish==2u { separation = vec2f(0.021,0.009); }
            if finish==39u { separation = vec2f(0.019,0.013)*smoothstep(0.035,0.45,abs(p.y)); }
            if finish==41u { separation = vec2f(0.092,0.019)*(0.5+motion.y*0.31); delay=0.027; }
            if finish==42u { separation = vec2f(0.034,0.016); delay=0.12; }
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
        case 6u: { sample_uv += vec2f(sin(surface.y*26.0+motion.x),cos(surface.x*22.0+motion.y))*0.047/fit; }
        case 29u: { mask=1.0-smoothstep(0.31,0.37,length(shape)); }
        case 30u: {
            let q=shape-vec2f(0,0.04);
            let arch=max(length(vec2f(q.x,min(q.y+0.11,0.0)))-0.22,q.y-0.36);
            mask=1.0-smoothstep(-0.009,0.009,arch);
        }
        case 31u: { mask=1.0-smoothstep(-0.011,0.008,box_distance(shape,vec2f(0.17,0.39),0.013)); }
        case 32u: { mask=1.0-smoothstep(0.10,0.49,abs(p.x))*0.85; }
        case 33u: { mask=0.25+0.75*exp(-dot(shape,shape)*9.0); }
        case 34u: { mask=1.0-0.54*exp(-p.y*p.y*36.0)*exp(-p.x*p.x*6.0); }
        case 35u: { sample_uv.x=0.5+abs(p.x); }
        case 36u: {
            let frame=max(abs(p.x),abs(p.y));
            let depth=clamp(floor(-log2(max(frame,0.018)))-1.0,0.0,5.0);
            sample_uv=0.5+p*exp2(depth);
            mask=1.0-depth*0.11;
        }
        case 37u: {
            floor_reflection=uv.y>0.73;
            if floor_reflection {
                sample_uv.y=1.46-uv.y;
                sample_uv.x+=0.012*sin(uv.y*190.0+motion.x);
                mask=0.32*(1.0-smoothstep(0.73,1.0,uv.y));
            }
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
        case 2u: { color += (grain-0.5)*0.085*level; }
        case 10u: {
            let dot_size = 0.16+level*0.44;
            mask *= mix(0.25,1.0,1.0-smoothstep(dot_size-0.1,dot_size,length(fract(surface*58.0)-0.5)));
        }
        case 11u, 18u, 19u: {
            var grid = surface*66.0;
            if finish==18u { grid=surface*13.0; }
            if finish==19u { grid=surface*72.0; }
            let local = abs(fract(grid)-0.5);
            let gap = smoothstep(0.36,0.48,max(local.x,local.y));
            mask *= 1.0-gap*select(0.31,0.67,finish!=18u);
            if finish==18u { color+=gap*0.055*settings.colors[2].rgb; }
            if finish==19u { mask*=0.57+0.43*(1.0-smoothstep(0.21,0.55,length(local))); }
        }
        case 12u, 20u: {
            let density=select(44.0,24.0,finish==20u);
            mask*=1.0-abs(sin(surface.y*density*3.1415927))*select(0.19,0.62,finish==20u);
        }
        case 13u: { mask*=0.48+0.52*smoothstep(0.1,0.7,fract((surface.x+surface.y)*71.0)+level*0.61); }
        case 14u: { mask*=0.68+0.32*noise(vec2f(surface.x*4.0,surface.y*215.0)); }
        case 15u: { mask*=0.76+0.24*abs(sin(surface.x*183.0)*cos(surface.y*183.0)); }
        case 16u: { color+=(noise(surface*120.0+motion*0.23)-0.5)*0.15*level; }
        case 17u: { color+=pow(grain,18.0)*level*0.22; }
        case 21u: {
            let stripes=fract(surface.x*48.0+vec3f(0,0.3333,0.6667));
            color*=0.58+0.61*(1.0-smoothstep(vec3f(0.23),vec3f(0.48),abs(stripes-0.5)));
            mask*=0.83+0.17*abs(cos(surface.y*130.0));
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
