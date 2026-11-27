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
        case 1u, 3u, 8u, 9u: {
            let reed = sin(flutes*6.2831853);
            var refraction = reed*finish_t(1u)*0.12;
            if finish==3u {
                // Bars / Stretch / Flip / Slide / Shade
                refraction=flutes*mix(0.02,0.22,finish_t(1u));
                sample_uv.y += (finish_t(3u)-0.5)*0.08*reed;
            }
            if finish==8u { refraction=reed*mix(0.004,0.04,finish_t(1u)); }
            if finish==9u {
                // Strips / Refraction / Layers / Angle / Edge
                let layers=finish_t(2u);
                let a=radians(finish_t(3u));
                let along=surface.x*cos(a)+surface.y*sin(a);
                let freq=mix(90.0,230.0,clamp(layers/4.0,0.0,1.0));
                refraction=reed*mix(0.01,0.08,finish_t(1u))*(0.7+0.3*layers)
                    +sin(along*freq)*0.009;
            }
            sample_uv.x += refraction/fit.x;
            mask = 0.74+0.26*smoothstep(-0.3,0.3,reed);
        }
        case 2u, 39u, 41u, 42u: {
            taps = 3u;
            // Frost / Grain size / Edge light
            if finish==2u { separation = vec2f(0.008,0.004)*mix(1.0,8.0,finish_t(0u))*finish_t(1u); }
            if finish==39u {
                // Focus / Focus band / Blur
                let band_center=finish_t(1u);
                let focus_band=1.0-smoothstep(0.0,0.42,abs(p.y-band_center*0.5));
                separation=vec2f(0.019,0.013)*finish_t(0u)*(0.45+0.55*focus_band);
                delay=0.012*finish_t(2u);
            }
            if finish==41u {
                // Length / Angle / Taper / Waver / Keep sharp
                let raw=vec2f(0.092,0.019)*finish_t(0u)*(0.5+motion.y*0.31);
                separation=rotate2(raw,finish_t(1u)*0.5)*mix(0.6,1.0,finish_t(2u));
                separation.y += 0.012*finish_t(3u)*sin(t+p.y*9.0);
            }
            if finish==42u {
                // Echoes / Lag / Fade / Tint / Add
                separation=vec2f(0.034,0.016)*finish_t(0u);
                delay=0.12*finish_t(1u);
            }
        }
        case 4u, 5u, 7u: {
            if finish==4u {
                // Columns / Gap / Round / Frost / Gloss
                let cols=max(1.0,round(finish_t(0u)));
                let gapw=0.30+finish_t(1u)*0.18;
                let grid=vec2f(uv.x*cols,uv.y*cols*0.45);
                let f=fract(grid)-0.5;
                let edge=mix(max(abs(f.x),abs(f.y)),length(f),finish_t(2u));
                let frost=(hash(floor(grid)+4.2)-0.5)*finish_t(3u);
                sample_uv += vec2f(frost*0.035,f.x*0.012*(0.4+finish_t(4u)))/fit;
                mask=1.0-smoothstep(gapw-0.06,gapw+0.02,edge)*0.86;
            }
            if finish==5u {
                // Blocks / Bevel / Refraction
                let blocks=max(4.0,finish_t(0u));
                let grid=vec2f(surface.x*blocks,surface.y*blocks*0.62);
                let f=fract(grid)-0.5;
                let off=hash(floor(grid)+4.2)-0.5;
                sample_uv += vec2f(off*0.06*finish_t(2u),f.x*0.02*finish_t(2u))/fit;
                let edge=max(abs(f.x),abs(f.y));
                mask=1.0-smoothstep(0.40-finish_t(1u)*0.12,0.49,edge)*0.85;
            }
            if finish==7u {
                // Panes / Edge width / Glass glow / Sun rays / Edges / Layout
                let panes=max(3.0,finish_t(0u));
                let pane_layout=clamp(finish_t(5u)/5.0,0.0,1.0);
                var grid=vec2f(surface.x*panes,surface.y*panes*mix(0.35,0.72,pane_layout));
                grid.y += floor(grid.x)*mix(-0.14,0.14,pane_layout);
                let f=fract(grid)-0.5;
                let edge=max(abs(f.x),abs(f.y));
                let edges=max(1.0,round(finish_t(4u)));
                let rim=abs(sin(edge*3.14159*edges));
                let ew=mix(0.06,0.20,finish_t(1u));
                sample_uv.x += f.x*0.018*finish_t(2u)/fit.x;
                sample_uv.y += f.y*0.012*finish_t(3u)/fit.y;
                mask=1.0-smoothstep(0.40-ew,0.49,edge)*0.72
                    +rim*smoothstep(0.34,0.48,edge)*0.22*finish_t(2u);
            }
        }
        case 6u: {
            let dir = radians(finish_t(2u));
            let wave = vec2f(cos(dir), sin(dir))*finish_t(0u);
            sample_uv += vec2f(sin(dot(surface,wave)*2.0+motion.x),cos(dot(surface,wave.yx)*2.0+motion.y))*0.08*finish_t(1u)/fit;
        }
        case 10u: {
            // Dot size / Dot angle / Dot fill
            let dots=max(2.0,finish_t(0u));
            let grid=fract(rotate2(surface,finish_t(1u))*dots)-0.5;
            let fill=finish_t(2u);
            mask *= mix(0.25,1.0,1.0-smoothstep(0.16*fill,0.30*fill,length(grid)));
        }
        case 19u: {
            // Pixels tall: quantize the sample rows.
            let rows=max(10.0,finish_t(0u));
            sample_uv.y=(floor(uv.y*rows)+0.5)/rows;
        }
        case 20u: {
            // Slats / Gap / Pixels / Angle / Drift: pixelation strength.
            let px=max(2.0,finish_t(2u));
            let quantized=(floor(sample_uv*px)+0.5)/px;
            sample_uv=mix(sample_uv,quantized,clamp(finish_t(2u)/200.0,0.0,1.0));
        }
        case 25u, 40u: {
            taps=3u;
            let base=vec2f(0.033,0.009)*select(1.0,0.6+motion.x*0.32,finish==40u);
            if finish==25u {
                // Split / Angle / Fringe
                separation=rotate2(base*finish_t(0u),radians(finish_t(1u)));
                delay=0.02*finish_t(2u);
            }
            if finish==40u {
                // Split / Angle / Wander / Radial / Keep color
                let wander=finish_t(2u)*motion.x*0.02;
                let radial=finish_t(3u)*dot(p,p)*0.05;
                separation=rotate2(base*finish_t(0u),radians(finish_t(1u)*0.5))
                    +vec2f(wander+radial,wander-radial);
            }
        }
        case 29u: {
            // Size / Softness / Shape / Surround fill / Gradient angle
            let sz=mix(0.18,0.44,finish_t(0u));
            let soft=mix(0.008,0.075,finish_t(1u));
            let d=mix(length(shape),box_distance(shape,vec2f(sz*0.92),sz*0.35),finish_t(2u)*0.6);
            mask=mix(finish_t(3u)*0.25,1.0,1.0-smoothstep(sz-soft,sz+soft,d));
        }
        case 30u: {
            // Width / Height / Wall glow / Rim / Openings
            let opens=max(1.0,round(finish_t(4u)));
            let q=vec2f(fract((shape.x+0.5)*opens)/opens-0.5/opens,shape.y-0.04);
            let hw=mix(0.08,0.30,finish_t(0u));
            let hh=mix(0.16,0.46,finish_t(1u));
            let arch=max(length(vec2f(q.x,min(q.y+0.11,0.0)))-hw,q.y-hh);
            mask=1.0-smoothstep(-0.009,0.009,arch);
            mask += finish_t(2u)*0.14*(1.0-smoothstep(0.02,0.16,abs(arch)));
        }
        case 31u: {
            // Width / Height / Bloom / Floor / Reflection
            let fw=mix(0.08,0.30,finish_t(0u));
            let fh=mix(0.16,0.46,finish_t(1u));
            let d=box_distance(shape,vec2f(fw,fh),0.013);
            let floor_y=mix(0.12,0.72,clamp(-finish_t(3u),0.0,1.0));
            let floor_glow=smoothstep(floor_y-0.08,floor_y+0.04,uv.y)
                *(1.0-smoothstep(floor_y+0.08,floor_y+0.20,uv.y));
            sample_uv.y=mix(sample_uv.y,1.46-uv.y,finish_t(4u)*floor_glow*0.8);
            mask=1.0-smoothstep(-0.011,0.008,d);
            mask += finish_t(2u)*0.16*floor_glow;
        }
        case 32u: {
            // Width / Sides / Top and bottom
            let w=mix(0.06,0.49,finish_t(0u));
            let side=finish_t(1u);
            let top=finish_t(2u);
            let dx=smoothstep(w*mix(0.55,1.0,side),w,abs(p.x));
            let dy=smoothstep(w*0.35*mix(0.5,1.0,top),w*0.7,abs(p.y))*top;
            mask=1.0-max(dx,dy)*0.85;
        }
        case 33u: {
            // Size / Darkness / Wander
            let center=shape+motion*finish_t(2u)*0.18;
            let sz=mix(5.0,22.0,finish_t(0u));
            let glow=exp(-dot(center,center)*sz);
            mask=mix(0.25+0.75*glow,glow*0.4,finish_t(1u));
        }
        case 34u: {
            // Height / Strength / Bottom / top
            let center=mix(-0.25,0.25,finish_t(0u));
            let dir=mix(-1.0,1.0,finish_t(2u));
            mask=1.0-finish_t(1u)*0.7*exp(-pow((p.y-center)*5.0,2.0))
                *exp(-p.x*p.x*mix(2.0,8.0,(dir+1.0)*0.5));
        }
        case 35u: {
            // Mode / Center / Segments
            let mode=clamp(finish_t(0u)/2.0,0.0,1.0);
            let seg=max(3.0,finish_t(2u));
            let shifted=uv.x+finish_t(1u)*0.37;
            let x=fract(shifted*seg)/seg;
            let fold=select(x,1.0-x,x>0.5);
            let mirrored=mix(fold,abs(fold-0.25)*2.0,mode);
            sample_uv.x=clamp(0.5+(mirrored-0.25)*mix(0.6,1.4,mode),0.0,1.0);
            let center=finish_t(1u);
            sample_uv.x=clamp(sample_uv.x+center*0.12,0.0,1.0);
            let bands=0.5+0.5*cos(shifted*seg*6.2831853+center*2.0);
            sample_uv.y=clamp(sample_uv.y+(seg/12.0)*0.06*(bands-0.5),0.0,1.0);
            mask *= 0.7+0.3*bands;
        }
        case 36u: {
            // Depth / Frame / Travel / Rotate / Fade
            let q=rotate2(p,finish_t(3u)*90.0);
            let depth=clamp(floor(-log2(max(length(q)*max(finish_t(1u),0.02),0.018)))-1.0,
                0.0,max(1.0,finish_t(0u)));
            sample_uv=0.5+q*exp2(depth)*(1.0+0.10*finish_t(2u)*cos(t));
            mask=1.0-depth*finish_t(4u)*0.16;
        }
        case 37u: {
            // Floor height / Fade / Ripple
            let fh=mix(0.55,0.93,finish_t(0u));
            floor_reflection=uv.y>fh;
            if floor_reflection {
                sample_uv.y=1.0+(fh-uv.y)*mix(0.2,1.1,finish_t(1u));
                sample_uv.x+=0.012*finish_t(2u)*sin(uv.y*190.0+motion.x);
                mask=0.32*finish_t(1u)*(1.0-smoothstep(fh,1.0,uv.y));
            }
        }
        case 38u: {
            // Length / Fade / Amount
            let freq=mix(6.0,34.0,finish_t(0u));
            let fade=finish_t(1u);
            sample_uv.y += sin(surface.x*freq+motion.x*1.8)*0.14*finish_t(2u)
                *mix(0.25,1.0,uv.y)*(0.6+0.4*fade);
        }
        case 43u: {
            // Rows / Width / Tear / Step / Color bands
            let rows=max(2.0,finish_t(0u));
            let row=floor(uv.y*rows);
            let key=hash(vec2f(row,3.0));
            let width=mix(0.4,1.4,finish_t(1u));
            let tear=(finish_t(2u)-0.5)*0.16*(key-0.5)*2.0;
            let steps=max(2.0,finish_t(3u));
            sample_uv.x=0.5+(p.x*width+tear)*(0.57+0.66*key);
            sample_uv.y=(floor(uv.y*steps)+0.5)/steps;
        }
        case 44u: {
            // Pixels / Steps / Gaps
            let px=max(2.0,finish_t(0u));
            let grid=vec2f(px,px*0.56);
            let column=floor(uv.x*grid.x);
            sample_uv.y += 0.037*(hash(vec2f(column,1.0))-0.5);
            let quantized=(floor(sample_uv*grid)+0.5)/grid;
            sample_uv=mix(sample_uv,quantized,finish_t(1u));
            let g=fract(uv*grid)-0.5;
            mask *= 1.0-finish_t(2u)*0.36*smoothstep(0.36,0.49,max(abs(g.x),abs(g.y)));
        }
        case 45u: {
            // Columns / Length / Amount / Steps / Direction
            let cols=max(2.0,finish_t(0u));
            let a=radians(finish_t(4u));
            let axis=vec2f(surface.x*cos(a)-surface.y*sin(a),surface.x*sin(a)+surface.y*cos(a));
            let column=floor(axis.x*cols);
            let steps=max(2.0,finish_t(3u));
            let amount=finish_t(2u);
            sample_uv.y=0.5+p.y*mix(0.35,1.25,finish_t(1u))
                *(0.55+0.75*hash(vec2f(column,2.0)))
                +amount*(hash(vec2f(column,5.0))-0.5)*0.10;
            sample_uv.y=floor(sample_uv.y*steps)/steps;
            sample_uv.x=mix(sample_uv.x,0.5+axis.x*0.5,amount*0.3);
        }
        case 46u: {
            // Blocks / Offset / Hits / Rate / Color tear
            let blocks=max(2.0,finish_t(0u));
            let block=floor(uv*vec2f(blocks,blocks*1.85));
            let key=hash(block+finish_t(1u)*13.0);
            let hits=finish_t(2u);
            let shift=smoothstep(mix(0.88,0.42,hits),mix(0.96,0.72,hits),key)
                *pow(0.5+0.5*sin(t*finish_t(3u)+key*22.0),4.0);
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
            color += (grain-0.5)*0.085*level;
            let edge=pow(0.5+0.5*sin(flutes*6.2831853),10.0);
            color += settings.colors[1].rgb*edge*finish_t(2u)*0.14*level; // Edge light
        }
        case 3u: { color *= 1.0-finish_t(4u)*0.28*smoothstep(0.05,0.45,abs(flutes)); } // Shade
        case 4u: {
            let cols=max(1.0,round(finish_t(0u)));
            let f=fract(vec2f(uv.x*cols,uv.y*cols*0.45))-0.5;
            color *= 1.0-(1.0-finish_t(4u))*0.28
                *smoothstep(0.05,0.42,f.y+0.5*finish_t(1u)); // Gloss
        }
        case 5u: {
            let blocks=max(4.0,finish_t(0u));
            let f=fract(vec2f(surface.x*blocks,surface.y*blocks*0.62))-0.5;
            color += settings.colors[2].rgb*finish_t(1u)*0.10
                *smoothstep(0.10,0.46,max(abs(f.x),abs(f.y))); // Bevel
        }
        case 7u: {
            let glow=finish_t(2u);
            let rays=finish_t(3u);
            let light=0.5+0.5*sin(surface.x*12.0+surface.y*5.0);
            color += (settings.colors[1].rgb*glow*0.07
                +settings.colors[2].rgb*rays*0.07)*light;
        }
        case 9u: {
            let edge=pow(0.5+0.5*sin(flutes*6.2831853),8.0);
            color += settings.colors[2].rgb*edge*finish_t(4u)*0.13*level; // Edge
        }
        case 11u, 18u, 19u: {
            if finish==18u {
                // Grid / Strength / Line
                let grid=surface*max(2.0,finish_t(0u));
                let local=abs(fract(grid)-0.5);
                let gap=smoothstep(0.36,0.48,max(local.x,local.y));
                mask *= 1.0-gap*mix(0.1,0.7,finish_t(1u));
                color += gap*mix(0.01,0.12,finish_t(2u))*settings.colors[2].rgb;
            } else {
                let grid=surface*max(2.0,finish_t(0u));
                let local=abs(fract(grid)-0.5);
                let gap=smoothstep(0.34+finish_t(1u)*0.1,0.48,max(local.x,local.y));
                mask *= 1.0-gap*select(0.31,0.67,finish==19u);
                if finish==11u {
                    mask *= 1.0-finish_t(2u)*0.22*hash(floor(grid)+3.0)*gap; // Variation
                }
            }
            if finish==19u {
                // Pixels tall / Dot size / Panel size / Seams / Hot pixels
                let dot_radius=mix(0.14,0.42,finish_t(1u));
                let panel=max(2.0,finish_t(2u));
                let panel_grid=fract(vec2f(surface.x*panel,surface.y*panel*0.55))-0.5;
                let dots=1.0-smoothstep(dot_radius,dot_radius+0.10,length(panel_grid));
                mask *= 0.55+0.35*dots;
                mask *= 1.0-mix(0.02,0.12,finish_t(3u))
                    *smoothstep(0.40,0.49,abs(panel_grid.x));
                let hot=smoothstep(mix(0.96,0.74,finish_t(4u)),1.0,
                    hash(floor(surface*max(10.0,finish_t(0u)*1.6))+7.0));
                color += settings.colors[2].rgb*hot*0.18*level;
            }
        }
        case 12u, 20u: {
            if finish==12u {
                // Amount / Pitch / Roll / Misregister / Vignette
                let density=mix(20.0,90.0,finish_t(1u));
                let roll=finish_t(2u)*3.1415927;
                let stripe=abs(sin(surface.y*density*3.1415927+roll));
                mask *= 1.0-stripe*mix(0.05,0.6,finish_t(0u));
                let mis=finish_t(3u)*0.10*stripe;
                color *= vec3f(1.0+mis,1.0,1.0-mis);
                mask *= 1.0-finish_t(4u)*0.34*smoothstep(0.2,0.72,length(p));
            } else {
                // Slats / Gap / Pixels / Angle / Drift
                let slats=max(4.0,finish_t(0u));
                let a=radians(finish_t(3u)*0.5);
                let v=vec2f(surface.x*cos(a)-surface.y*sin(a),surface.x*sin(a)+surface.y*cos(a));
                let stripe=abs(sin(v.y*slats*3.1415927+finish_t(4u)*1.7));
                mask *= 1.0-stripe*mix(0.14,0.72,finish_t(1u));
            }
        }
        case 13u: {
            // Line density / Angle / Ink
            let a=radians(finish_t(1u));
            let v=vec2f(surface.x*cos(a)-surface.y*sin(a),surface.x*sin(a)+surface.y*cos(a));
            mask *= 1.0-finish_t(2u)*0.72
                *smoothstep(0.1,0.7,fract((v.x+v.y)*finish_t(0u))+level*0.61);
        }
        case 14u: {
            // Strength / Direction / Sheen
            let a=radians(finish_t(1u));
            let v=vec2f(surface.x*cos(a)-surface.y*sin(a),surface.x*sin(a)+surface.y*cos(a));
            let n=noise(vec2f(v.x*4.0,v.y*215.0));
            mask *= 1.0-finish_t(0u)*0.42*n;
            color += settings.colors[2].rgb*finish_t(2u)*0.10*smoothstep(0.55,0.95,n);
        }
        case 15u: {
            // Texture / Weave size / Paint
            let scale=180.0/max(1.0,finish_t(1u));
            let weave=abs(sin(surface.x*scale)*cos(surface.y*scale));
            mask *= 1.0-finish_t(0u)*0.30*weave;
            color=mix(color,settings.colors[2].rgb,finish_t(2u)*0.10*weave);
        }
        case 16u: {
            // Amount / Size / Snow
            let sz=mix(40.0,220.0,finish_t(1u));
            let n=noise(surface*sz+motion*0.23);
            color += (n-0.5)*0.16*finish_t(0u)*level;
            let snow=smoothstep(0.78,0.98,noise(surface*sz*0.7+4.0))*finish_t(2u);
            color += vec3f(snow)*0.10*level;
        }
        case 17u: {
            // Glints / Grain size / Texture
            let size=mix(90.0,420.0,finish_t(1u));
            let speck=hash(floor(surface*size)+f32(settings.seed));
            let base=pow(speck,mix(14.0,26.0,finish_t(2u)));
            color += vec3f(base)*finish_t(0u)*0.24*level;
        }
        case 21u: {
            // Lines / Triads / Curve / Roll / Bloom
            let lines=max(10.0,finish_t(0u));
            let curve=finish_t(2u)*0.6*sin(surface.y*6.0);
            let roll=finish_t(3u)*0.15;
            let stripes=fract(surface.x*lines+curve+roll
                +vec3f(0.0,0.3333,0.6667)*finish_t(1u));
            color *= 0.58+0.61*(1.0-smoothstep(vec3f(0.23),vec3f(0.48),abs(stripes-0.5)));
            color += settings.colors[2].rgb*finish_t(4u)*0.08
                *(0.5+0.5*cos(stripes.r*6.2831853));
            mask *= 0.83+0.17*abs(cos(surface.y*130.0));
        }
        case 22u: {
            // Lines / Offset / Amount / Sway / Shape
            let lines=max(10.0,finish_t(0u));
            let v=surface.x*lines+finish_t(1u)*3.0+motion.y*finish_t(3u)*2.7
                +sin(surface.y*12.0)*2.7;
            let sine=0.5+0.5*sin(v);
            let shaped=mix(sine,1.0-abs(fract(v/6.2831853)*2.0-1.0),finish_t(4u));
            mask *= mix(1.0,mix(0.55,1.0,shaped),finish_t(2u));
        }
        case 23u: {
            // Amount / Cool shadows / Warm highs / Contrast / Obsidian
            let graded0=mix(color,vec3f(0.23,0.16,0.55)+level*0.55,finish_t(0u)*0.30);
            let graded1=graded0+vec3f(0.10,0.16,0.35)*finish_t(1u)*(1.0-level)*0.32
                +vec3f(0.35,0.20,0.08)*finish_t(2u)*level*0.30;
            let graded2=mix(graded1,
                clamp((graded1-0.5)*mix(1.0,1.8,finish_t(3u))+0.5,vec3f(0),vec3f(1)),0.5);
            color=graded2*mix(1.0,0.74,finish_t(4u));
        }
        case 24u: {
            // Strength / Warmth / Position
            let pos=vec2f(mix(-0.25,0.65,finish_t(2u)),0.18);
            let glow=band(length(p+pos+motion*0.04),0.18)*finish_t(0u)*0.36;
            let warm=mix(settings.colors[2].rgb,vec3f(1.0,0.62,0.28),finish_t(1u)*0.7);
            color += warm*glow;
        }
        case 25u: { color *= vec3f(1.0+finish_t(2u)*0.12,1.0,1.0-finish_t(2u)*0.10); } // Fringe
        case 26u: {
            // Haze / Tint / Depth
            let n=mist(shape*mix(1.5,6.0,finish_t(2u))+motion*0.34);
            let tint=mix(settings.colors[1].rgb,settings.colors[2].rgb,finish_t(1u)*0.6);
            color += n*tint*finish_t(0u)*0.28;
        }
        case 27u: {
            // Amount / Spread / Speed
            let spread=mix(2.0,9.0,finish_t(1u));
            color=mix(color,settings.colors[1].rgb,
                finish_t(0u)*(0.18+0.14*sin(p.y*spread+motion.x*finish_t(2u))));
        }
        case 28u: {
            // Glow / Width / Sweeps / Angle / Base
            let a=radians(finish_t(3u));
            let v=vec2f(p.x*cos(a)-p.y*sin(a),p.x*sin(a)+p.y*cos(a));
            let sweeps=max(1.0,finish_t(2u));
            let width=mix(0.03,0.22,finish_t(1u));
            let stripe=0.5+0.5*cos(v.x*sweeps*6.2831853+motion.x*0.81);
            color += settings.colors[2].rgb*finish_t(0u)*0.16*band(stripe-0.75,width);
            color += settings.colors[1].rgb*finish_t(4u)*0.07;
        }
        case 29u: {
            let a=radians(finish_t(4u)*0.5);
            let g=0.5+0.5*dot(vec2f(cos(a),sin(a)),shape);
            color += settings.colors[1].rgb*g*0.10; // Gradient angle
        }
        case 30u: {
            color += settings.colors[2].rgb*finish_t(3u)*0.10*band(shape.y+0.30,0.06); // Rim
        }
        case 31u: {
            color += settings.colors[2].rgb*finish_t(2u)*0.10
                *band(box_distance(shape,vec2f(0.2,0.3),0.013),0.05); // Bloom
        }
        case 37u: { if floor_reflection { color*=mix(0.95,0.72,finish_t(1u)); } }
        case 40u: { color=mix(color,color.bgr,finish_t(4u)*0.35); } // Keep color
        case 41u: {
            color=mix(color,background+max(color-background,vec3f(0))*1.16,
                finish_t(4u)*0.45); // Keep sharp
        }
        case 42u: {
            color *= 1.0-finish_t(2u)*0.24; // Fade
            color=mix(color,color*settings.colors[2].rgb*1.8,finish_t(3u)*0.35); // Tint
            color += settings.colors[1].rgb*finish_t(4u)*0.05; // Add
        }
        case 43u: {
            let wave=0.5+0.5*sin(uv.y*max(2.0,finish_t(0u))*6.2831853);
            let tint=mix(vec3f(0.90,1.0,1.10),vec3f(1.10,0.90,1.05),wave);
            color=mix(color,color*tint,finish_t(4u)*0.8); // Color bands
        }
        case 46u: {
            let tear=finish_t(4u)*0.10*(0.5+0.5*sin(t*2.0+p.y*14.0));
            color *= vec3f(1.0+tear,1.0-tear*0.5,1.0+tear*0.4); // Color tear
        }
        case 47u: {
            let coordinate = rotate2(shape,finish_t(1u)).y*finish_t(0u);
            let distance = abs(fract(coordinate)-0.5);
            let thickness = mix(0.04,0.43,finish_t(3u));
            let line = 1.0-smoothstep(thickness,thickness+0.06,distance);
            mask *= mix(1.0,line,finish_t(2u));
        }
        default: {}
    }
    return mix(background,color,clamp(mask,0.0,1.0));
}
