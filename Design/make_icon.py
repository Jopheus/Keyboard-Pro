import sys
V = {
 "light": dict(bg1="#FFFFFF", bg2="#DCDCE2", skirt1="#4A4A4E", skirt2="#1C1C1E",
               top1="#5C5C61", top2="#2C2C2E", bar="#FFFFFF", ring1="#3A3A3C", ring2="#636366",
               ringop=(0.55,0.28), shadow=0.35, hl=0.22),
 "dark":  dict(bg1="#2C2C2E", bg2="#000000", skirt1="#6E6E73", skirt2="#2C2C2E",
               top1="#8E8E93", top2="#48484A", bar="#FFFFFF", ring1="#AEAEB2", ring2="#D1D1D6",
               ringop=(0.75,0.38), shadow=0.6, hl=0.25),
 "tinted":dict(bg1="#000000", bg2="#000000", skirt1="#9A9A9A", skirt2="#5A5A5A",
               top1="#E6E6E6", top2="#ADADAD", bar="#000000", ring1="#FFFFFF", ring2="#FFFFFF",
               ringop=(0.55,0.25), shadow=0.0, hl=0.0),
}
def svg(v):
    c = V[v]
    o1,o2 = c["ringop"]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
 <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c['bg1']}"/><stop offset="1" stop-color="{c['bg2']}"/></linearGradient>
 <linearGradient id="skirt" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c['skirt1']}"/><stop offset="1" stop-color="{c['skirt2']}"/></linearGradient>
 <linearGradient id="top" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c['top1']}"/><stop offset="1" stop-color="{c['top2']}"/></linearGradient>
 <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{c['ring2']}"/><stop offset="1" stop-color="{c['ring1']}"/></linearGradient>
 <linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="{c['hl']}"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
 <filter id="sh" x="-30%" y="-30%" width="160%" height="170%"><feGaussianBlur stdDeviation="28"/></filter>
</defs>
<rect width="1024" height="1024" fill="url(#bg)"/>
<!-- haptic pulse rings -->
<rect x="104" y="104" width="816" height="816" rx="230" fill="none" stroke="url(#ring)" stroke-width="14" opacity="{o2}"/>
<rect x="160" y="160" width="704" height="704" rx="190" fill="none" stroke="url(#ring)" stroke-width="18" opacity="{o1}"/>
<!-- shadow -->
<rect x="250" y="320" width="524" height="490" rx="120" fill="#000" opacity="{c['shadow']}" filter="url(#sh)"/>
<!-- keycap skirt -->
<rect x="232" y="232" width="560" height="560" rx="126" fill="url(#skirt)"/>
<!-- keycap top face -->
<rect x="276" y="251" width="472" height="458" rx="97" fill="url(#top)"/>
<rect x="276" y="251" width="472" height="458" rx="97" fill="url(#hl)"/>
<!-- return arrow -->
<path transform="translate(512 480) scale(1.22) translate(-515 -478)" d="M588 396 V516 H442 M486 472 L442 516 L486 560" fill="none" stroke="{c['bar']}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round" opacity="0.95"/>
</svg>'''
for v in V:
    open(f"{v}.svg","w").write(svg(v))
