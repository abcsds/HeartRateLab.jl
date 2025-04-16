module Input
using Base.Filesystem: mktemp

using XDF: XDF
# TODO: LSL streams once Dagger streaming is stable

"""
    read_xdf(infile::String)

Reads an XDF file with RR-intervals.
The file should contain one RR-interval per line.

Arguments:
    infile: the input file name

Returns:
    an array with the read data
"""
function read_xdf(infile::String)
    # Read the XDF file
    data = XDF.read_xdf(infile)
    # Find the stream with "RR" in the name
    rr_idx = findfirst(x -> occursin("RR", x["name"]), data)
    #TODO: time management with the XDF timestamps
    return Int16.(data[rr_idx]["data"])
end

"""
    read_txt(infile::String)

Reads a text file with RR-intervals.
The file should contain one RR-interval in milliseconds per line: the same way Kubios exports them.

Arguments:
    infile: the input file name

Returns:
    an array with the read data
"""
function read_txt(infile::String)
    a=read(open(infile, "r"), String)
    return parse.(Int16, filter!(e->e!="", split(a, r"[^\d.]")))
end

"""
    read_wfdb(record::String,annotator::String)

Uses external `ann2rr` function from the WFDB Software Package to read the RR-intervals from a WFDB record.

Arguments:
    record: the record name
    annotator: the annotator of the record

Returns:
    an array with the read data
"""
function read_wfdb(record::String, annotator::String)
    run(pipeline(`ann2rr -r "$record" -a "$annotator" -i s -c`; stdout=mktemp()))
    a = read_txt(temp)
    rm(temp)
    return Int16.(round(a*1000; digits=0)) # TODO: Interpolate?
end

end # module Input
