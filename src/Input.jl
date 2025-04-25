module Input
using Base.Filesystem: mktemp
using XDF: XDF
# TODO: LSL streams once Dagger streaming is stable: lsl and bluetooth

"""
    read_xdf(infile::String)

Reads an XDF file with RR-intervals.
The file should contain one RR-interval stream, marked with "RR" in the name.

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
    return Float32.(data[rr_idx]["data"])
end

"""
    read_txt(infile::String)

Reads a text file with RR-intervals.
The file should contain one RR-interval in milliseconds per line (the same way Kubios exports them).

Arguments:
    infile: the input file name

Returns:
    an array with the read data
"""
function read_txt(infile::String)
    a=read(open(infile, "r"), String)
    return parse.(Float32, filter!(e->e!="", split(a, r"[^\d.]")))
end

"""
    read_wfdb(record::String,annotator::String)

Uses external `ann2rr` function from the WFDB Software Package to read the RR-intervals from a WFDB record.
A possible alternative is to use the [wfdb-python package](https://github.com/MIT-LCP/wfdb-python/blob/main/wfdb/processing/hr.py).

Arguments:
    record: the record name
    annotator: the annotator of the record

Returns:
    an array with the read data
"""
function read_wfdb(record::String, annotator::String)
    temp, io = mktemp()
    run(pipeline(`ann2rr -r "$record" -a "$annotator" -i s -c`; stdout=io))
    a = read_txt(temp)
    rm(temp)
    return  round.(Int, a*1000)
end

export read_xdf
export read_txt
export read_wfdb

end # module Input
