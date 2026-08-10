#!/usr/bin/env python3
"""
HeartRateLab feature computational graph -> Graphviz DOT.

A computational graph is ABOUT THE EDGES: every "is computed from" relationship
must be a clear, solid, traceable arrow.  We therefore let Graphviz `dot` do the
layered DAG layout with crossing minimisation, and render every dependency
(including multi-parent and cross-domain representation reuse) as a visible edge.

Nodes coloured by analysis domain; representations filled, scalar features
outlined.  Derived from the live registry in src/Features.jl.
"""
import os, sys

DOMAINS = {
    "time": dict(title="Time & Statistics", accent="#7c53c9", fill="#efe9fb"),
    "freq": dict(title="Frequency",         accent="#2f8a44", fill="#e6f3e9"),
    "geom": dict(title="Geometric",         accent="#c07d1e", fill="#fbefdc"),
    "nl":   dict(title="Nonlinear",         accent="#0f9488", fill="#dff4f1"),
}
DIST = {"Normal":"#4c78d8","Gamma":"#e8912a","Beta":"#4e9a4e","LogNormal":"#b452c9",None:"#c2c2cc"}
REPS = {"diff","length","duration","pgram","max_t","px","py","histogram","renyi","dfa","dfa1"}

# name -> (domain, distribution)
NODES = {
 "mean":("time","Normal"),"sdnn":("time","Gamma"),"median":("time","Normal"),
 "max":("time","Normal"),"min":("time","Normal"),
 "diff":("time",None),"length":("time",None),"duration":("time",None),
 "mean_hr":("time","Normal"),"sdann":("time","Gamma"),"cvnni":("time","Normal"),
 "std_hr":("time","Gamma"),"median_hr":("time","Normal"),
 "max_hr":("time","Normal"),"range":("time","Gamma"),"range_hr":("time","Gamma"),
 "min_hr":("time","Normal"),"sdsd":("time","Gamma"),"rmssd":("time","Gamma"),
 "pnn50":("time","Beta"),"pnn20":("time","Beta"),"rRR":("time","Gamma"),"cvsd":("time","Gamma"),
 "pgram":("freq",None),"max_t":("freq",None),
 "ulf":("freq","Gamma"),"vlf":("freq","Gamma"),"lf":("freq","Gamma"),"hf":("freq","Gamma"),
 "tp":("freq","Gamma"),"lf_peak":("freq","Normal"),"hf_peak":("freq","Normal"),
 "lf_hf_ratio":("freq","LogNormal"),"lf_relative":("freq","Beta"),"hf_relative":("freq","Beta"),
 "lf_percentage":("freq","Gamma"),"hf_percentage":("freq","Gamma"),
 "px":("geom",None),"py":("geom",None),"histogram":("geom",None),
 "sd1":("geom","Gamma"),"sd2":("geom","Gamma"),
 "triangular_index":("geom","Gamma"),"tinn":("geom","Gamma"),
 "sd2_sd1":("geom","LogNormal"),"sd1_sd2_area":("geom","LogNormal"),
 "cvi":("geom","Normal"),"ccsi":("geom","LogNormal"),
 "apen":("nl","Normal"),"sampen":("nl","Normal"),"hurst":("nl","Beta"),
 "shan_en":("nl","Normal"),"svd_en":("nl","Normal"),"fuzzyen":("nl","Normal"),
 "perm_en":("nl","Normal"),"spec_en":("nl","Normal"),"mse":("nl","Normal"),
 "renyi":("nl",None),"dfa":("nl",None),
 "renyi0":("nl","Normal"),"renyi1":("nl","Normal"),"renyi2":("nl","Normal"),
 "dfa1":("nl",None),"dfa2":("nl","Normal"),
}
LABELS = {"sd2_sd1":"sd2 / sd1","lf_hf_ratio":"lf / hf","sd1_sd2_area":"sd1·sd2 area"}

# every conceptual dependency parent -> child (multi-parent listed explicitly)
EDGES = [
 ("mean","mean_hr"),("mean","sdann"),("mean","cvnni"),("mean","cvsd"),
 ("sdnn","std_hr"),("sdnn","cvnni"),
 ("median","median_hr"),
 ("max","max_hr"),("max","range"),("max","range_hr"),
 ("min","min_hr"),("min","range"),("min","range_hr"),
 ("diff","sdsd"),("diff","rmssd"),("diff","pnn50"),("diff","pnn20"),("diff","rRR"),
 ("length","pnn50"),("length","pnn20"),
 ("sdsd","cvsd"),("rmssd","cvsd"),
 ("duration","max_t"),("max_t","ulf"),
 ("pgram","ulf"),("pgram","vlf"),("pgram","lf"),("pgram","hf"),("pgram","tp"),
 ("pgram","lf_peak"),("pgram","hf_peak"),
 ("lf","lf_hf_ratio"),("lf","lf_relative"),("hf","lf_hf_ratio"),("hf","hf_relative"),
 ("tp","lf_relative"),("tp","hf_relative"),
 ("lf_relative","lf_percentage"),("hf_relative","hf_percentage"),
 ("px","sd1"),("px","sd2"),("py","sd1"),("py","sd2"),
 ("sd1","sd2_sd1"),("sd1","sd1_sd2_area"),("sd1","cvi"),("sd1","ccsi"),
 ("sd2","sd2_sd1"),("sd2","sd1_sd2_area"),("sd2","cvi"),("sd2","ccsi"),
 ("length","px"),("length","py"),
 ("histogram","triangular_index"),("histogram","tinn"),("length","triangular_index"),
 ("length","hurst"),("pgram","spec_en"),
 ("renyi","renyi0"),("renyi","renyi1"),("renyi","renyi2"),
 ("dfa","dfa1"),("dfa1","dfa2"),
]
# RawData feeds every node computed directly from the raw series
RAW_TARGETS = ["mean","sdnn","median","max","min","diff","length","duration",
               "pgram","px","py","histogram",
               "apen","sampen","hurst","shan_en","svd_en","fuzzyen","perm_en","mse",
               "renyi","dfa"]

def q(s): return '"'+str(s).replace('"','\\"')+'"'

def node_stmt(n):
    dom,dist=NODES[n]; d=DOMAINS[dom]; lab=LABELS.get(n,n)
    if n in REPS:
        return (f'    {q(n)} [label={q(lab)}, fillcolor="{d["accent"]}", '
                f'color="{d["accent"]}", fontcolor="white"];')
    badge=DIST[dist]
    lab_h=(f'<<table border="0" cellborder="0" cellspacing="0" cellpadding="0"><tr>'
           f'<td><font color="{badge}" point-size="15">&#9679;</font></td>'
           f'<td width="5"></td><td><font color="#222736">{lab}</font></td></tr></table>>')
    return (f'    {q(n)} [label={lab_h}, fillcolor="white", color="{d["accent"]}", '
            f'fontcolor="#222736"];')

# Right-hand clusters (Geometric, Frequency) get shoved to a deeper rank so the
# layout is a rectangular 2x2 instead of one tall column.  We do this by adding
# invisible rank-forcing edges from a deep left-column node into their entry
# representations, and by making the (few) direct RawData->rep edges to them
# non-constraining so they don't fight the ranking.  All *real* arrows stay.
PUSH_RIGHT   = ["histogram","px","py","pgram","max_t"]   # right-cluster entry reps
RAW_NOCONSTR = {"px","py","histogram","pgram"}           # of those, the raw-fed ones
PUSH_ANCHOR  = "cvsd"                                     # deepest Time node (rank 4)

def emit(clusters=True, two_column=True):
    o=[]
    o.append('digraph HRL {')
    # Horizontal BANNER layout: rankdir=TB puts RawData on top and hangs the four
    # domain clusters below as parallel columns, side-by-side (wide & short) — the
    # same shape as the mermaid layout, but keeping our domain colours + dist badges.
    # (Do NOT use ratio=fill/size=..! — it stretches the graph and leaves dead gaps.)
    o.append('  rankdir=TB; bgcolor="white"; nodesep=0.24; ranksep="0.42 equally";')
    o.append('  splines=spline; compound=true; newrank=true; pad=0.3;')
    o.append('  labelloc="t"; fontname="Helvetica-Bold"; fontsize=25;')
    o.append('  label=<<b>HeartRateLab &#8212; Feature Computational Graph</b>'
             '<br/><font point-size="13" color="#5b6172">One IBI series &#8594; 11 memoised '
             'representations &#8594; 53 HRV features. Every arrow is an &#8220;is computed '
             'from&#8221; dependency.</font><br/> >;')
    o.append('  node  [shape=box, style="rounded,filled", fontname="Helvetica-Bold", '
             'fontsize=12, height=0.34, margin="0.10,0.045", penwidth=1.7];')
    o.append('  edge  [penwidth=1.7, arrowsize=0.72];')

    o.append('  RawData [label=<<b>RawData</b><br/><font point-size="9">IBI / RR series</font>>, '
             'shape=box, style="rounded,filled", fillcolor="#1b2237", fontcolor="#eef1f8", '
             'penwidth=0, width=1.5, height=1.0];')

    if clusters:
        for dom,d in DOMAINS.items():
            o.append(f'  subgraph cluster_{dom} {{')
            title=d["title"].replace("&","&amp;")
            o.append(f'    label=<<b>{title}</b>>; labeljust="l"; fontsize=15; '
                     f'fontcolor="{d["accent"]}"; style="rounded,filled"; '
                     f'fillcolor="{d["fill"]}"; color="{d["accent"]}"; penwidth=1.6; margin=12;')
            for n in NODES:
                if NODES[n][0]==dom: o.append(node_stmt(n))
            o.append('  }')
    else:
        for n in NODES: o.append(node_stmt(n))

    # ---- legend (anchored in the left column, under RawData) ---------------
    dots=("".join(f'<font color="{DIST[k]}">&#9679;</font> '
                  for k in ["Normal","Gamma","Beta","LogNormal"]))
    legend=('<<table border="1" color="#cfd3dc" cellborder="0" cellspacing="5" '
            'cellpadding="2" bgcolor="white"><tr><td align="left"><b>Legend</b></td>'
            '<td></td></tr>'
            '<tr><td bgcolor="#6b7180" width="30">&#160;</td>'
            '<td align="left">representation (memoised, reused)</td></tr>'
            '<tr><td bgcolor="white" border="1" color="#6b7180" width="30">&#160;</td>'
            '<td align="left">scalar feature</td></tr>'
            f'<tr><td>{dots}</td>'
            '<td align="left">Normal / Gamma / Beta / LogNormal</td></tr>'
            '<tr><td><b>&#8594;</b></td><td align="left">is computed from</td></tr>'
            '</table>>')
    o.append(f'  legend [shape=none, margin=0, label={legend}, fontname="Helvetica", fontsize=11];')
    o.append('  {rank=same; RawData; legend;}')
    o.append('  RawData -> legend [style=invis];')

    for t in RAW_TARGETS:
        extra=", constraint=false" if (two_column and t in RAW_NOCONSTR) else ""
        o.append(f'  RawData -> {q(t)} [color="#8c93a6", penwidth=1.3, arrowsize=0.55{extra}];')
    for a,b in EDGES:
        col=DOMAINS[NODES[a][0]]["accent"]
        o.append(f'  {q(a)} -> {q(b)} [color="{col}"];')

    if two_column:
        o.append('  // rank-forcing (invisible): push Geometric & Frequency to the right')
        for r in PUSH_RIGHT:
            o.append(f'  {q(PUSH_ANCHOR)} -> {q(r)} [style=invis, weight=8];')

    o.append('}')
    return "\n".join(o)

if __name__=="__main__":
    import subprocess
    here=os.path.dirname(os.path.abspath(__file__))
    dot=emit(clusters=True, two_column=False)   # TB banner: clusters side-by-side
    dotf=os.path.join(here,"computational-graph.dot")
    with open(dotf,"w") as f: f.write(dot)
    svgf=os.path.join(here,"computational-graph.svg")
    pngf=os.path.join(here,"computational-graph.png")
    subprocess.run(["dot","-Tsvg",dotf,"-o",svgf],check=True)
    subprocess.run(["dot","-Tpng","-Gdpi=150",dotf,"-o",pngf],check=True)
    print("wrote",dotf,svgf,pngf,"| nodes",len(NODES)+1,
          "edges",len(EDGES)+len(RAW_TARGETS))
