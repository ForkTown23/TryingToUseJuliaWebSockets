using CSV
using SimpleWebsockets
using HTTP
using CurricularAnalytics
using CurricularAnalyticsDiff
using JSON

# HTTP.listen! and HTTP.serve! are the non-blocking versions of HTTP.listen/HTTP.serve
server = HTTP.serve() do request::HTTP.Request
    @show request
    @show request.method
    @show HTTP.header(request, "Content-Type")
    #bod = HTTP.parse_multipart_form(request)
    # using bod[1].name is seemingly a no-go. until you figure it out, use hard-coded order: [1] is the method and [2] onwards is the content 
    # println(String(read(bod[1].data)))
    #@show request.body
    request_string = String(request.body)
    request_strings = split(request_string, "&")
    try
        response = ""
        method = split(request_strings[1], "=")[2]
        # this is going to be chained if-elses, julia has no native switch, and I don't want to add another package
        if (method == "add-course")
            # do the add course stuff
            response = "Alright! Let's add a course!"
        elseif (method == "add-prereq")
            response = "Alright! Let's add a prereq!"
        elseif (method == "remove-course")
            response = "Alright! Let's remove a course!"
        elseif (method == "remove-prereq")
            response = "Alright! Let's remove a prereq!"
        else
            throw(ArgumentError("Hey, I'm not sure what method you're trying to call. Please try again :)"))
        end
        return HTTP.Response("$response")
    catch e
        return HTTP.Response(400, "Error: $e")
    end
end
# HTTP.serve! returns an `HTTP.Server` object that we can close manually
close(server)