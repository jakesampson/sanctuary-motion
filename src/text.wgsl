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

// The only source of font size. Rows and repeats add spacing around this
// glyph height; they never change it.
fn glyph_height() -> f32 {
    return min(0.095*settings.text_layout.x,0.80/max(1.0,f32(settings.text_style.x)));
}

fn glyph_ratio(line: u32) -> f32 {
    let slot=glyphs[line];
    return f32(slot&65535u)/max(1.0,f32(slot>>16u));
}

fn glyph_width(line: u32, height: f32) -> f32 {
    return clamp(height*glyph_ratio(line)*0.75/max(settings.composition,0.2),0.008,0.92);
}

fn centred(value: f32, window: f32, flip: bool) -> f32 {
    let w=clamp(window,0.02,1.0);
    let at=(value-(1.0-w)*0.5)/w;
    return select(at,1.0-at,flip);
}

fn text_pattern(p: vec2f, style: u32, phase: f32) -> f32 {
    let lines=settings.text_style.x;
    let mode=settings.text_style.y;
    let density=settings.text_shape.x;
    let spacing=settings.text_shape.z;
    let aspect=settings.composition;
    let radial=p*vec2f(max(aspect,1.0),max(1.0,1.0/aspect));
    let r=length(radial);
    let inner=0.12+settings.text_shape.y*0.26;
    let spin=phase*6.2831853;
    var q=p;
    // Curved treatments map text onto polar coordinates. Flip the glyph sampling
    // so the warped letters stay upright/readable instead of mirrored.
    var flip_x=false;
    var flip_y=false;
    let height=glyph_height();
    let pitch_y=height*(1.0+spacing*0.4);
    let window_y=clamp(height/pitch_y,0.02,1.0);

    // Letter Rain keeps glyphs upright in columns and drops them with a small
    // stable per-column offset, instead of rotating and scrambling every row.
    if mode==0u && style==28u {
        let column_width=glyph_width(0u,height);
        let column_cell=column_width*(1.0+spacing*0.25);
        let columns=max(1.0,floor(1.0/column_cell));
        let column=q.x*columns+floor(columns*0.5);
        let column_id=i32(floor(column));
        let count=i32(lines);
        let line=u32((column_id%count+count)%count);
        let width=glyph_width(line,height);
        let cell_x=1.0/columns;
        let glyph_x=centred(fract(column),clamp(width/cell_x,0.02,1.0),flip_x);
        let drop_pitch=1.0/max(1.0,floor(1.0/(height*(1.0+spacing*0.25))));
        let offset=hash(vec2f(f32(column_id),2.0))*0.35;
        let y=fract(q.y/drop_pitch-phase*0.35+offset);
        let glyph_y=centred(y,clamp(height/drop_pitch,0.02,1.0),false);
        return glyph_line(line,vec2f(glyph_x,glyph_y));
    }

    if mode==2u || (mode==0u && (style==0u || style>=30u)) {
        if style==45u && mode==0u { q.y+=0.012*sin(q.x*24.0+spin); }
        let row=q.y/pitch_y+f32(lines)*0.5;
        if row<0.0 || row>=f32(lines) { return 0.0; }
        let line=u32(row);
        let width=glyph_width(line,height);
        let glyph_x=select(0.5+q.x/width,0.5-q.x/width,flip_x);
        return glyph_line(line,vec2f(glyph_x,centred(fract(row),window_y,flip_y)));
    }
    if mode==1u {
        let row=(q.y-0.42)/pitch_y+f32(lines);
        if row<0.0 || row>=f32(lines) { return 0.0; }
        let line=u32(row);
        let width=glyph_width(line,height);
        let cell=width*(1.0+spacing*0.25);
        let x=fract((q.x-phase+floor(row)*0.17)/cell);
        return glyph_line(line,vec2f(centred(x,width/cell,flip_x),centred(fract(row),window_y,flip_y)));
    }
    if mode==3u {
        let scroll=fract(q.y+0.5+phase);
        let row=scroll*f32(lines);
        let line=u32(row);
        let width=glyph_width(line,height);
        let cell=width*(1.0+spacing*0.25);
        let x=fract((q.x-phase*0.25+0.5)/cell);
        return glyph_line(line,vec2f(centred(x,width/cell,flip_x),centred(fract(row),window_y,flip_y)));
    }

    // Density and spacing change the gaps between copies, never the glyph size.
    let rows=max(1.0,floor(1.0/(height*mix(1.7,1.05,density))));
    let pitch=1.0/rows;
    let window=clamp(height/pitch,0.02,1.0);
    var gate=1.0;
    switch style {
        case 2u: { gate=0.62+0.38*band(fract(q.y*rows*0.5)-0.5,0.22); }
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
            var arch_gate=1.0;
            if style!=9u {
                // Fade out below the arch base instead of clamping to y=0.
                // Clamping repeats one glyph row downward as vertical streaks.
                let arch_y=v.y-0.15;
                arch_gate=1.0-smoothstep(0.0,0.04,arch_y);
                v.y=min(arch_y,0.0);
            }
            let radius=length(v);
            let angle=atan2(v.y,v.x);
            // Start arch text away from the folded centre; otherwise glyph rows
            // are clipped into stacked fragments at the bottom seam.
            let inner_gate=select(smoothstep(inner-0.03,inner,radius),
                                  smoothstep(inner+0.05,inner+0.12,radius),style!=9u);
            gate=arch_gate*inner_gate*(1.0-smoothstep(0.47,0.58,radius));
            q=vec2f(angle/6.2831853,radius-0.5);
            // Upper arc: radial distance grows upward, so flip glyph vertical.
            // Lower arc: angle runs right-to-left, so flip glyph horizontal.
            if style==5u || style==20u || v.y<0.0 { flip_y=true; } else { flip_x=true; }
            // Twin Arches folds both halves into one polar coordinate. Reverse
            // the left half's arc coordinate instead of flipping each glyph:
            // letterforms and word order stay forward, and the -1 offset makes
            // the two halves meet seamlessly at the bottom centre.
            if style==20u && radial.x<0.0 { q.x=-q.x-1.0; }
        }
        case 6u, 23u: {
            q=rotate_text(q,1.5707963);
            if style==23u { gate=0.68+0.32*band(fract(q.x*7.0)-0.5,0.18); }
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
    let width=glyph_width(line,height);
    let cell=1.0/max(1.0,floor(1.0/(width*(1.0+spacing*0.25))));
    var x=fract(q.x/cell);
    if style==12u { x=fract(q.x/cell+f32(row_id%2)*0.5); }
    if style==29u { x=fract(q.x/cell+0.05*sin(spin)); }
    let glyph_x=centred(x,clamp(width/cell,0.02,1.0),flip_x);
    let glyph_y=centred(fract(row),window,flip_y);
    let stroke=glyph_line(line,vec2f(glyph_x,glyph_y));
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
