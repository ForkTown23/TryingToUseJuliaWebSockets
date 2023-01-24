using CSV
using SimpleWebsockets
using HTTP
using CurricularAnalytics
using CurricularAnalyticsDiff

# HTTP.listen! and HTTP.serve! are the non-blocking versions of HTTP.listen/HTTP.serve
server = HTTP.serve() do request::HTTP.Request
    @show request
    @show request.method
    @show HTTP.header(request, "Content-Type")
    bod = HTTP.parse_multipart_form(request)
    # using bod[1].name is seemingly a no-go. until you figure it out, use hard-coded order: [1] is the method and [2] onwards is the content 
    println(String(read(bod[1].data)))
    @show request.body
    try
        return HTTP.Response("HELLO")
    catch e
        return HTTP.Response(400, "Error: $e")
    end
end
# HTTP.serve! returns an `HTTP.Server` object that we can close manually
close(server)