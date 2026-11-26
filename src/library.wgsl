// Each look returns midtone illumination and highlight intensity.
fn box_distance(p: vec2f, half_size: vec2f, radius: f32) -> f32 {
    let q = abs(p) - half_size + radius;
    return length(max(q, vec2f(0))) + min(max(q.x,q.y),0.0) - radius;
}

fn band(d: f32, width: f32) -> f32 {
    return exp(-abs(d)/width);
}

fn emitter(d: f32, power: f32) -> vec2f {
    return vec2f(band(d,0.064)*0.84,band(d,0.013)*power);
}

fn line_segment(p: vec2f, a: vec2f, b: vec2f) -> f32 {
    let axis = b-a;
    return length(p-a-axis*clamp(dot(p-a,axis)/dot(axis,axis),0.0,1.0));
}

fn library_look(look: u32, uv: vec2f, t: f32, drift: vec2f, seed: f32) -> vec2f {
    let q = uv-0.5;
    // Fit symmetric objects inside both portrait and ultrawide canvases.
    let aspect = settings.composition;
    let p = q*vec2f(max(1.0,aspect),max(1.0,1.0/aspect));
    let r = length(p);
    let a = atan2(p.y,p.x);
    let shimmer = 0.86+0.14*drift.y;
    let sweep = sin(p.x*6.0+seed+drift.x);
    switch look {
        case 6u, 21u, 29u, 74u, 80u: {
            var frequency = 32.0;
            var sharpness = 9.0;
            var shape = 0.42+0.58*pow(cos(p.y*9.0+drift.y+p.x*4.0),2.0);
            switch look {
                case 21u: { frequency = 13.0; sharpness = 3.0; shape = band(p.y+0.08*drift.y,0.34); }
                case 29u: { frequency = 180.0; shape = 0.38+0.62*noise(vec2f(p.x*19.0,drift.x)+seed); }
                case 74u: { frequency = 115.0; sharpness = 18.0; shape = mist(vec2f(p.x*5.0,p.y*1.4)+drift+seed); }
                case 80u: { frequency = 17.0; sharpness = 4.0; shape = mist(vec2f(p.x*2.0,p.y*6.0)+drift+seed); }
                default: {}
            }
            let col = p.x*frequency+0.24*sin(p.y*8.0+drift.x);
            let light = pow(0.5+0.5*cos(col*3.14159),sharpness)*shape*shimmer;
            return vec2f(light*0.73,light*0.86);
        }
        case 7u, 35u, 43u, 65u: {
            var origin = vec2f(0.10*drift.x,0.48);
            var frequency = 13.0;
            var sharpness = 10.0;
            if look == 7u { origin.y = -0.18; frequency = 7.0; sharpness = 5.0; }
            if look == 43u { origin = vec2f(-0.36,-0.52); frequency = 17.0; sharpness = 2.0; }
            if look == 65u { frequency = 9.0; sharpness = 3.0; }
            let v = p-origin;
            let angle = atan2(v.y,v.x);
            let ray = pow(0.5+0.5*cos(angle*frequency+drift.y+seed*0.2),sharpness);
            let haze = 0.46+0.54*mist(v*5.0+drift+seed);
            let taper = exp(-length(v)*1.8)*haze;
            let broken = select(1.0,0.25+0.75*noise(vec2f(length(v)*12.0,angle*8.0)+drift),look==35u);
            return vec2f(taper*(0.24+ray)*broken,taper*ray*0.83*broken);
        }
        case 8u, 22u, 23u, 24u, 46u, 47u, 49u, 50u, 71u, 75u: {
            let radius = 0.30+0.012*drift.x;
            var distance = r-radius;
            let orbit = 0.57+0.43*cos(a*2.0+drift.y);
            switch look {
                case 8u, 47u: {
                    let v = vec2f(p.x,p.y-0.43);
                    let d = length(v)-0.37-0.012*drift.y;
                    let rim = emitter(d,select(0.94,0.67,look==8u));
                    return rim+select(vec2f(0),vec2f(band(p.y-0.07,0.035)*0.35,0),look==8u);
                }
                case 22u: {
                    let slat = band(fract((p.y+p.x*0.25)*24.0+drift.y*0.15)-0.5,0.11);
                    return vec2f(slat*0.76,slat*0.9)*(1.0-smoothstep(radius-0.05,radius,r));
                }
                case 24u: { return vec2f(band(distance,0.10)*step(0.0,distance),band(distance,0.007)*orbit); }
                case 46u: {
                    let waves = pow(0.5+0.5*cos(r*29.0+drift.x),3.0)*exp(-3.0*r);
                    return vec2f(waves,waves*0.52);
                }
                case 49u: {
                    let dots = pow(0.5+0.5*cos(a*47.0+drift.x),6.0);
                    return vec2f(band(distance,0.044)*0.35,band(distance,0.014)*dots*0.75);
                }
                case 50u: {
                    let rings = pow(0.5+0.5*cos(r*118.0+0.8*sin(3.0*a)+drift.y),10.0);
                    return vec2f(rings*orbit*0.7,rings*orbit*0.83)*exp(-1.5*r);
                }
                case 71u: {
                    let disc = 1.0-smoothstep(-0.012,0.006,distance);
                    return vec2f(disc*(0.62-p.y)+band(distance,0.055)*0.38,disc*(0.31-p.y)*shimmer);
                }
                case 75u: {
                    let disk = band(p.y-p.x*0.29,0.028)*exp(-9.0*abs(p.x));
                    return emitter(distance,orbit*0.86)+vec2f(disk,disk*0.60)*step(radius*0.72,r);
                }
                default: { return emitter(distance,shimmer); }
            }
        }
        case 9u, 44u, 54u: {
            var light = vec2f(0);
            for (var i=0u; i<7u; i++) {
                let index = f32(i);
                let size = 0.33*pow(0.75,index)*(1.0+drift.x*0.05);
                var v = p+vec2f(0,0.014*index);
                var corner = 0.015;
                if look==44u { v = v+vec2f(sin(index+drift.y)*size*0.22,0); corner=0.027; }
                if look==54u { v=p; corner=0.0; }
                let d = box_distance(v,vec2f(size*select(1.0,1.42,look==9u),size),corner);
                light = max(light,emitter(d,0.91-index*0.065)*(0.95-index*0.075));
            }
            return light;
        }
        case 10u, 12u, 14u: {
            var output = vec2f(0);
            for (var n=0u; n<8u; n++) {
                let i=f32(n)-3.5;
                var v=p-vec2f(i*0.073,0.03*sin(i+drift.y));
                var size=vec2f(0.045,0.23-abs(i)*0.021);
                var corner=0.036;
                if look==12u { v.x += v.y*0.16; size.x=0.019; corner=0.008; }
                if look==14u { v = p.yx-vec2f(i*0.065,i*0.028); size=vec2f(0.015,0.25-abs(i)*0.038); corner=0.009; }
                let d=box_distance(v,size,corner);
                let facet = 0.36+0.64*pow(cos(i*0.7+drift.x+v.y*7.0),2.0);
                output=max(output,vec2f(1.0-smoothstep(-0.02,0.014,d),band(d,0.022))*facet);
            }
            return output;
        }
        case 11u, 36u, 40u, 48u, 58u, 67u: {
            var v = p.y+0.11*sweep;
            switch look {
                case 11u: { v=p.x+p.y*0.42; return emitter(v+0.14*drift.x,0.34)+vec2f(band(v-0.23,0.09)*0.4,0); }
                case 36u: {
                    let slats = pow(0.5+0.5*cos(p.y*170.0),4.0);
                    return vec2f(slats,slats*0.72)*band(p.y+p.x*0.43+0.15*drift.y,0.13);
                }
                case 40u: {
                    let ribbon = emitter(v+0.14*sin(p.x*3.0+drift.y),0.66);
                    return max(ribbon,emitter(p.y-0.17*sweep+0.12,0.54));
                }
                case 48u: { return emitter(v-0.15,0.7)*vec2f(0.71,0.5+0.5*pow(cos(p.x*96.0),4.0)); }
                case 58u: { return emitter(fract(v*11.0+drift.y*0.16)-0.5,0.69)*0.61; }
                default: {
                    let lane = p.y-p.x*0.37;
                    let cut = noise(vec2f(p.x*18.0+drift.x,floor(lane*22.0))+seed);
                    return vec2f(band(fract(lane*22.0)-0.5,0.053)*cut*0.8,0.19*cut*band(fract(lane*22.0)-0.5,0.10));
                }
            }
        }
        case 13u, 45u: {
            let wave = 0.034*sin(a*5.0+drift.y)+0.012*cos(a*9.0+drift.x);
            if look==13u {
                let rim = r-0.29-wave;
                let facet = 0.25+0.75*pow(cos(a*3.0+drift.x),2.0);
                return vec2f(band(rim,0.052),band(rim-0.009,0.019))*facet;
            }
            let optical = pow(0.5+0.5*cos(54.0*(r+wave)+drift.x),4.0);
            let falloff=1.0-smoothstep(0.27,0.43,r);
            return vec2f(optical*falloff,optical*falloff*(0.49+0.4*cos(a+drift.y)));
        }
        case 15u, 16u, 19u, 68u, 69u, 70u, 72u, 73u: {
            var d = box_distance(p,vec2f(0.30,0.19),0.051);
            var fill = false;
            switch look {
                case 15u: { d=box_distance(p-vec2f(0,0.04),vec2f(0.085,0.31),0.007); fill=true; }
                case 16u: { d=(length((p+vec2f(0,0.18))*vec2f(1.0,3.1))-0.31)/2.0; fill=true; }
                case 19u: { d=min(0.5-abs(q.x),0.5-abs(q.y)); }
                case 69u: { d=box_distance(p,vec2f(0.24,0.24),0.07); fill=true; }
                case 70u: {
                    let v=p-vec2f(0,0.14);
                    d=length(vec2f(v.x,min(v.y,0.0)))-0.15;
                    fill=true;
                }
                case 72u: { d=box_distance(p-vec2f(0,0.07),vec2f(0.10,0.24),0.085); fill=true; }
                case 73u: { return emitter(p.x+0.055*drift.x,0.71)*vec2f(1.3,0.72); }
                default: {}
            }
            let mask=1.0-smoothstep(-0.015,0.008,d);
            let gradient=clamp(0.68+p.y*0.94+drift.y*0.12,0.1,1.0);
            return (emitter(d,select(0.98,0.4,fill))+
                select(vec2f(0),vec2f(mask*0.82,mask*gradient*0.64),fill))*shimmer;
        }
        case 17u, 18u, 20u, 41u, 42u, 62u, 79u, 81u: {
            let haze=mist(p*4.0+drift*0.6+seed);
            switch look {
                case 17u: { return vec2f(band(1.0-uv.y,0.11),band(1.0-uv.y,0.035))*shimmer; }
                case 18u: {
                    let ramp=smoothstep(-0.45,0.45,q.x+q.y*0.38+0.24*drift.x);
                    return vec2f(ramp*0.82,pow(ramp,2.0)*0.60);
                }
                case 20u: {
                    let mesh=exp(-4.0*length(p+vec2f(0.24*drift.x,0.28)))+0.8*exp(-5.0*length(p-vec2f(0.29,0.24*drift.y)));
                    return vec2f(mesh,mesh*mesh*0.81);
                }
                case 41u: {
                    let caustic=pow(0.5+0.5*sin(p.x*22.0+4.0*haze+drift.x+p.y*1.2),7.0);
                    return vec2f(caustic*haze,caustic*haze*haze);
                }
                case 42u: { return vec2f(haze*0.69,smoothstep(0.45,0.72,haze)*0.93); }
                case 62u: {
                    let v=vec2f(p.x+p.y*0.8,p.y);
                    let stroke=mist(v*vec2f(39.0,5.0)+drift+seed);
                    let mark=smoothstep(0.36,0.72,stroke*haze*1.55);
                    return vec2f(mark*0.58,mark*shimmer);
                }
                case 79u: {
                    let ink=smoothstep(0.34,0.57,haze);
                    return vec2f(ink*0.65,(1.0-ink)*haze*0.72);
                }
                default: {
                    let dots=length(fract(p*64.0)-0.5);
                    let mask=1.0-smoothstep(haze*0.55-0.06,haze*0.55+0.04,dots);
                    return vec2f(mask*haze,mask*haze*haze*0.71);
                }
            }
        }
        case 25u, 26u, 27u, 28u: {
            let v=p+vec2f(0,0.025);
            let d=min(box_distance(v,vec2f(0.024,0.32),0.006),
                      box_distance(v+vec2f(0,0.087),vec2f(0.18,0.021),0.005));
            let solid=1.0-smoothstep(-0.008,0.005,d);
            let spokes=pow(0.5+0.5*cos(a*21.0+drift.x),7.0)*exp(-6.0*r);
            switch look {
                case 25u: { return emitter(d,0.7)+vec2f(spokes*0.67,solid*shimmer*0.64); }
                case 26u: { return (emitter(d,0.51)+vec2f(spokes,spokes*0.34))*(1.0-solid); }
                case 27u: { return emitter(d,0.81)*vec2f(0.7,0.5+0.5*sin(p.y*18.0+drift.y)); }
                default: {
                    let curtain=pow(0.5+0.5*cos(p.x*123.0),10.0)*band(p.y+0.05*sweep,0.33);
                    return vec2f(curtain*0.58,curtain*0.32)+emitter(d,0.77)*shimmer;
                }
            }
        }
        case 30u, 31u, 32u, 33u: {
            let fine=drifting_lights(p, t+0.4,seed,true);
            if look==30u { return vec2f(band(p.y+0.11*sweep,0.23)*0.2,fine*0.92); }
            if look==31u { return vec2f(band(q.y-0.45,0.13)*0.51,fine*0.38+drifting_lights(p+drift*0.04,t,seed+3.0,true)*0.58); }
            if look==32u { let bokeh=drifting_lights(p*0.88,t,seed,false); return vec2f(bokeh*0.45,bokeh*1.01); }
            let cells=p*12.0;
            let center = fract(cells)-0.5;
            let twinkle=pow(0.5+0.5*sin(hash(floor(cells)+seed)*6.2831853+t),3.0);
            let star=band(center.x,0.039)*band(center.y,0.20)+band(center.y,0.039)*band(center.x,0.20);
            return vec2f(fine*0.15,star*twinkle*0.95);
        }
        case 34u, 38u, 39u, 55u, 56u, 59u, 60u, 63u, 64u: {
            var grid=p*14.0;
            if look==34u { grid=p*vec2f(48.0,46.0); }
            if look==38u { grid=p*vec2f(12.0,23.0); }
            if look==39u {
                grid=p*vec2f(14.0,9.0);
                let column=hash(vec2f(floor(grid.x),seed));
                grid.y=grid.y*mix(0.57,1.26,column)+column;
            }
            if look==55u { grid=p*vec2f(15.0,59.0)+vec2f(0,0.6*sweep); }
            if look==56u { grid+=vec2f(0.45*sin(p.y*10.0+drift.x),0.4*sweep); }
            if look==59u { grid=p*vec2f(16.0,6.0); }
            if look==60u { grid=p*vec2f(17.0,13.0); }
            if look==63u || look==64u { grid=p*7.0; }
            let cell=floor(grid);
            let f=fract(grid)-0.5;
            let random=hash(cell+seed);
            let wave=0.61+0.39*sin(cell.x*0.6+cell.y*0.4+t+random*2.0);
            var mask=1.0-smoothstep(0.41,0.47,max(abs(f.x),abs(f.y)));
            var value=wave;
            switch look {
                case 34u: { mask=1.0-smoothstep(0.12,0.35,length(f)); value=band(p.y+0.15*sweep,0.29)*(0.45+0.55*sweep*sweep)*shimmer; }
                case 38u: { mask*=step(0.28,random)*step(fract(cell.y/8.0+cell.x*0.5),0.46); }
                case 39u: { value*=smoothstep(0.22,0.6,random); }
                case 55u: { mask=band(f.y,0.095); value*=pow(0.5+0.5*cos(grid.x+drift.x+f.y),3.0); }
                case 56u: { value=(0.15+0.85*fract((cell.x+cell.y)*0.5)*2.0)*wave; }
                case 59u: { mask=band(abs(f.x)-0.5,0.027); value=band(q.y-0.29-drift.y*0.12,0.075); }
                case 60u: { mask=select(band(f.x,0.038),band(f.y,0.038),random>0.5); value*=step(0.48,random)*0.58; }
                case 63u: { value*=smoothstep(0.22,0.56,random); }
                case 64u: { value=0.64+0.24*wave-0.19*step(random,0.15); }
                default: {}
            }
            return vec2f(mask*value*0.83,mask*value*0.81);
        }
        case 37u, 51u, 52u, 53u: {
            if look==37u {
                let v=vec2f(p.x,min(p.y-0.12,0.0));
                let radius=length(v);
                let line=band(fract(radius*22.0+drift.x*0.18)-0.5,0.085);
                let segments=smoothstep(0.27,0.51,noise(vec2f(atan2(v.y,v.x)*20.0,floor(radius*22.0))+seed+drift.y*0.1));
                return vec2f(line,line*segments)*smoothstep(0.18,0.24,radius)*segments;
            }
            if look==51u {
                let v=p/0.34;
                let z=sqrt(max(0.0,1.0-dot(v,v)));
                let longitude=atan2(v.x,z);
                let latitude=asin(clamp(v.y,-1.0,1.0));
                let line=max(band(fract((longitude+drift.x*0.34)*2.0)-0.5,0.09),band(fract(latitude*2.0)-0.5,0.085));
                let mask=(1.0-smoothstep(0.96,1.0,length(v)))*0.82;
                return vec2f(line,line*shimmer)*mask+emitter(r-0.34,0.29)*0.46;
            }
            if look==52u {
                var distance=10.0;
                let angle=0.47+0.43*drift.x;
                for (var n=0u; n<8u; n++) {
                    let v=vec3f(select(-1.0,1.0,(n&1u)!=0u),select(-1.0,1.0,(n&2u)!=0u),select(-1.0,1.0,(n&4u)!=0u));
                    for (var axis=0u; axis<3u; axis++) {
                        if (n&(1u<<axis))!=0u { continue; }
                        var next=v;
                        next[axis]=1.0;
                        let x=vec2f(cos(angle),sin(angle));
                        let z=vec2f(-x.y,x.x);
                        let u=vec2f(dot(x,v.xz),v.y+0.47*dot(z,v.xz))*0.18;
                        let w=vec2f(dot(x,next.xz),next.y+0.47*dot(z,next.xz))*0.18;
                        distance=min(distance,line_segment(p,u,w));
                    }
                }
                return emitter(distance,0.91);
            }
            var hoops=vec2f(0);
            for (var n=0u; n<4u; n++) {
                let y=(f32(n)-1.5)*0.13;
                let d=(length(vec2f(p.x,(p.y-y)*4.0))-0.30)*0.38;
                hoops=max(hoops,emitter(d,0.51)*(0.65+0.30*cos(f32(n)+t)));
            }
            return hoops;
        }
        case 57u, 61u: {
            let depth = max(0.008,q.y+0.01);
            let perspective=vec2f(q.x/depth,0.28/depth);
            let lines=max(band(fract(perspective.x*2.0)-0.5,0.055),band(fract(perspective.y+drift.y*0.24)-0.5,0.044));
            let ripple=band(fract(length(p-vec2f(0,0.53))*9.0+0.18*drift.x)-0.5,0.064);
            let ground=select(lines,ripple,look==61u)*smoothstep(0.018,0.40,depth);
            return vec2f(ground*0.85+band(q.y,0.04)*0.32,ground*0.67);
        }
        case 66u, 76u, 77u, 78u: {
            let sweep_y=q.y-0.26*drift.y;
            if look==66u { return emitter(sweep_y-0.14,0.91); }
            let d=box_distance(p,vec2f(0.38,0.18),0.03);
            let inside=1.0-smoothstep(-0.01,0.013,d);
            let scan=pow(0.5+0.5*cos(p.y*170.0+drift.x*2.0),5.0);
            let spot=band(length(p+vec2f(0.36,0.21)+drift*0.06),0.15)
                +band(length(p-vec2f(0.36,0.21)+drift*0.06),0.15);
            if look==77u { return vec2f(scan*0.4+spot*0.67,scan*band(sweep_y,0.14)*0.61); }
            return vec2f(spot*0.86+inside*scan*0.38,inside*scan*spot*0.59+band(d,0.014)*select(0.18,0.72,look==78u));
        }
        default: { return vec2f(0); }
    }
}
