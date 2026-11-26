@group(0) @binding(2) var<storage, read> glyphs: array<u32>;

// Atlas layout mirrors text.rs: twelve widths/heights, then packed alpha rows.
fn glyph_pixel(line: u32, x: u32, y: u32) -> f32 {
    let position = y*1024u+x;
    let word = glyphs[12u+line*24576u+position/4u];
    return f32((word >> ((position%4u)*8u)) & 255u)/255.0;
}

fn glyph_line(line: u32, point: vec2f) -> f32 {
    let slot = glyphs[line];
    if slot==0u || any(point<vec2f(0)) || any(point>vec2f(1)) { return 0.0; }
    let size=vec2u(slot&65535u,slot>>16u);
    let xy=point*vec2f(size-1u);
    let base=vec2u(xy);
    let next=min(base+1u,size-1u);
    let blend=fract(xy);
    let upper=mix(glyph_pixel(line,base.x,base.y),glyph_pixel(line,next.x,base.y),blend.x);
    let lower=mix(glyph_pixel(line,base.x,next.y),glyph_pixel(line,next.x,next.y),blend.x);
    return mix(upper,lower,blend.y);
}

fn rotate_text(p: vec2f, a: f32) -> vec2f {
    let c=cos(a);
    let s=sin(a);
    return vec2f(c*p.x-s*p.y,s*p.x+c*p.y);
}

fn text_pattern(p: vec2f, style: u32, phase: f32) -> f32 {
    let lines=settings.text_style.x;
    let mode=settings.text_style.y;
    let density=settings.text_shape.x;
    let spacing=settings.text_shape.z;
    let size=settings.text_layout.x;
    let aspect=settings.composition;
    let radial=p*vec2f(max(aspect,1.0),max(1.0,1.0/aspect));
    let r=length(radial);
    let inner=0.12+settings.text_shape.y*0.26;
    let spin=phase*6.2831853;
    var q=p;

    if mode==2u || (mode==0u && (style==0u || style>=30u)) {
        let line_step=min(0.23*size,0.80/f32(lines))*(0.80+spacing*0.40);
        if style==45u && mode==0u { q.y+=0.012*sin(q.x*24.0+spin); }
        let row = q.y/line_step+f32(lines)*0.5;
        if row<0.0 || row>=f32(lines) { return 0.0; }
        let line=u32(row);
        let slot=glyphs[line];
        let ratio=f32(slot&65535u)/max(1.0,f32(slot>>16u));
        let width=clamp(line_step*0.75*ratio/aspect,0.008,0.93);
        return glyph_line(line,vec2f(0.5+q.x/width,(fract(row)-0.12)/0.76));
    }
    if mode==1u {
        let height=min(0.13*size,0.36)*(0.8+spacing*0.4);
        let v=(q.y-0.42)/height+0.5;
        if v<0.0 || v>1.0 { return 0.0; }
        let gap=mix(0.08,0.18,spacing);
        let period=max(f32(lines),1.0);
        let t=fract(q.x/period-phase)*period;
        let line=min(u32(floor(t)),lines-1u);
        let local=fract(t);
        return glyph_line(line,vec2f(local/(1.0-gap),(v-0.12)/0.76));
    }
    if mode==3u {
        let scroll=fract(q.y+0.5+phase);
        let row=scroll*f32(lines);
        return glyph_line(u32(row),vec2f(q.x*1.35+0.5,(fract(row)-0.14)/(0.65*min(size,1.3))));
    }

    var rows=mix(11.0,31.0,density)/size;
    var gate=1.0;
    switch style {
        case 2u: { rows*=0.56; }
        case 3u: { gate=0.45+0.55*fract((floor(q.x*10.0)+floor(q.y*8.0))*0.5)*2.0; }
        case 4u, 21u: {
            let strip=abs(q.x);
            gate=select(0.0,1.0,strip>0.21 && strip<0.39);
            if style==21u { gate=max(gate,1.0-smoothstep(0.073,0.10,strip)); }
            q=rotate_text(q,1.5707963);
        }
        case 5u, 9u, 20u: {
            var v=radial;
            if style==20u { v.x=abs(v.x)-0.31; }
            if style!=9u { v.y=min(v.y-0.15,0.0); }
            let radius=length(v);
            // Screen y grows downward, so +atan2 walks the arc backwards.
            var u=-atan2(v.y,v.x)/6.2831853;
            if style==20u && radial.x<0.0 { u=-u; }
            gate=smoothstep(inner-0.03,inner,radius)*(1.0-smoothstep(0.47,0.58,radius));
            q=vec2f(u,radius-0.5);
        }
        case 6u, 23u, 28u: {
            q=rotate_text(q,1.5707963);
            if style==23u { rows*=1.8; }
            if style==28u { q.x+=fract(phase+hash(vec2f(floor(q.y*rows),2.0))); }
        }
        case 7u: { gate=0.15+0.85*band(q.x-sin(spin)*0.32,0.145); }
        case 8u: { gate=0.30+0.70*pow(0.5+0.5*cos(spin+floor(q.y*rows)*1.34),2.0); }
        case 10u: { gate=0.23+0.77*band(q.y-0.32*sin(spin),0.060); }
        case 11u: { q=rotate_text(q,select(-0.38,0.38,q.y<0.0)); }
        case 13u: { gate=0.20+0.80*max(1.0-smoothstep(0.085,0.11,abs(radial.x)),1.0-smoothstep(0.065,0.09,abs(q.y+0.07))); }
        case 14u: { gate=smoothstep(inner-0.02,inner,r); }
        case 15u: { gate=smoothstep(inner-0.02,inner,abs(radial.x)+abs(radial.y)); }
        case 16u: { gate=smoothstep(inner-0.026,inner,max(abs(q.x)*0.90,abs(q.y))); }
        case 17u: { q=rotate_text(q,0.33); }
        case 18u: { gate=smoothstep(-0.23,0.34,q.y); }
        case 19u: { q.x=abs(q.x); }
        case 22u: { gate=smoothstep(inner-0.02,inner,max(abs(q.x),abs(q.y))); }
        case 25u: { gate=0.57+0.43*sin(spin+floor(q.y*rows)*0.48); }
        case 26u: { gate=0.14+0.86*band(q.y,0.16); }
        case 27u: { gate=smoothstep(0.11,0.20,abs(q.x)); }
        case 29u: { gate=0.22+0.78*pow(abs(cos(spin+floor(q.y*rows)+floor(q.x*23.0))),4.0); }
        default: {}
    }
    let row=q.y*rows+floor(rows*0.5);
    let row_id=i32(floor(row));
    let count=i32(lines);
    let line=u32((row_id%count+count)%count);
    let slot=glyphs[line];
    let ratio=f32(slot&65535u)/max(1.0,f32(slot>>16u));
    let repeats=max(1.0,round(rows*aspect/(max(0.7,ratio)*0.72+spacing)));
    var x=fract(q.x*repeats);
    if style==12u { x=fract(q.x*repeats+f32(row_id%2)*0.5); }
    if style==28u || style==29u { x=fract(q.x*repeats+0.05*sin(spin)); }
    let stroke=glyph_line(line,vec2f((x-0.055)/0.89,(fract(row)-0.09)/mix(0.8,0.55,spacing)));
    return stroke*gate;
}

fn mix_text(background: vec3f, paint: vec3f, alpha: f32, style: u32) -> vec3f {
    var value=paint;
    switch style {
        case 1u: { value=1.0-(1.0-background)*(1.0-paint); }
        case 2u: { value=select(2.0*background*paint,1.0-2.0*(1.0-background)*(1.0-paint),background>vec3f(0.5)); }
        case 3u: { value=(1.0-2.0*paint)*background*background+2.0*paint*background; }
        case 4u: { value=background*paint; }
        case 5u: { value=min(background+paint,vec3f(1.0)); }
        case 6u: { value=min(background/max(1.0-paint,vec3f(0.01)),vec3f(1.0)); }
        case 7u: { value=abs(background-paint); }
        default: {}
    }
    return mix(background,value,clamp(alpha,0.0,1.0));
}

fn text_layer(source: vec3f, uv: vec2f) -> vec3f {
    if settings.text_style.x==0u { return source; }
    let style=settings.text_style.z;
    let p=uv-0.5-settings.text_layout.yz;
    let phase=settings.text_layout.w;
    let spin=phase*6.2831853;
    let background=settings.text_flags.x;
    var base=source*(1.0-settings.text_accent.a);
    if background==1u { base=vec3f(0); }
    if background==2u { base=vec3f(0,1,0); }

    var alpha=text_pattern(p,style,phase);
    var paint=settings.text_color.rgb;
    var bleed=0.0;
    let accent=settings.text_accent.rgb;
    var radius=settings.text_shape.w*0.019;
    if style>=30u && style<=43u { radius+=0.006; }
    if radius>0.0 {
        bleed=0.25*(text_pattern(p+vec2f(radius,0),style,phase)
                   +text_pattern(p-vec2f(radius,0),style,phase)
                   +text_pattern(p+vec2f(0,radius),style,phase)
                   +text_pattern(p-vec2f(0,radius),style,phase));
    }

    switch style {
        case 24u, 32u, 35u, 36u: {
            alpha=max(0.0,bleed-alpha*0.75);
            if style==32u { alpha*=1.25; paint=mix(paint,accent,0.45); }
            if style==35u { alpha*=0.55+0.45*smoothstep(-0.2,0.08,p.x-p.y); }
            if style==36u { alpha*=0.3+0.70*abs(sin(p.x*76.0+p.y*41.0+spin)); }
            paint=mix(paint,accent,0.56);
        }
        case 30u: { bleed+=0.21*band(p.y,0.022); }
        case 31u: { bleed*=0.92+0.08*cos(spin*3.0); paint=mix(paint,accent,0.31); }
        case 33u: { bleed*=0.68+0.32*cos(spin); }
        case 34u: {
            paint=vec3f(0.89,0.91,0.95)*(0.28+0.72*abs(sin((p.y+0.03)*19.0)));
            bleed=max(bleed,text_pattern(p-vec2f(0.015,0.03),style,phase)*0.75);
        }
        case 37u, 39u, 40u, 41u, 43u: {
            var direction=vec2f(0.024,-0.06);
            if style==39u { direction=vec2f(0,0.105); }
            if style==40u { direction=vec2f(sin(spin)*0.115,0.025); }
            if style==41u { direction=vec2f(0.085,0.036); }
            if style==43u { direction=vec2f(0,0.039); }
            for (var step_index=1u; step_index<=4u; step_index++) {
                let f=f32(step_index)/4.0;
                bleed=max(bleed,text_pattern(p-direction*f,style,phase)*(0.5-0.28*f));
            }
            if style==41u { paint=mix(paint,vec3f(0.55,0.8,1.0),0.32); }
        }
        case 38u: { paint=mix(paint,vec3f(0.60,0.94,1.0),0.5+0.5*sin(p.x*24.0+spin)); }
        case 42u: { paint=mix(paint,accent,0.72*band(p.x-sin(spin)*0.35,0.13)); }
        case 44u: { paint=mix(source,mix(paint,accent,0.52),0.37); }
        default: {}
    }
    if settings.text_flags.y==1u || style==30u {
        alpha*=0.72+0.28*abs(sin(uv.y*224.0));
    }
    let opacity=settings.text_color.a;
    let light=clamp(bleed*(0.34+settings.text_shape.w*0.85),0.0,0.82);
    let with_glow=mix_text(base,accent,light*opacity,1u);
    return mix_text(with_glow,paint,alpha*opacity,settings.text_style.w);
}
