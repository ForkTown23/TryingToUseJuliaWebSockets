using Pkg
#=Pkg.add(name="SimpleWebsockets", version="0.1.4")
Pkg.add(name="HTTP")
Pkg.add(name="CSV")
Pkg.add(name="CurricularAnalytics")=#
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
    println("A\nA\nA\n")
    #= That's for multipart forms, i.e. sending fat files. What if we remove that for the ones that are just commands
    bod = HTTP.parse_multipart_form(request)=#
    # using bod[1].name is seemingly a no-go. until you figure it out, use hard-coded order: [1] is the method and [2] is the content 
    # println(String(read(bod[1].data)))
    #= this is for recieving a curriculum csv and reading it
    bod = String(request.body)
    println(bod) =#
    #=csv = split(bod, "\n")[5:end-3]
    println(csv) =#
    #= # write the contents to a file
    open("newfile.csv", "w") do file
        for row in csv
            write(file, row)
            write(file, "\n")
        end
    end
    curr = read_csv("./newfile.csv")=#
    # this is for not multipart encode crap
    bod = String(request.body)
    println("BODY")
    println(bod)
    try
        return HTTP.Response("$(blocking_factor(curr.curriculum, 4))")
    catch e
        return HTTP.Response(400, "Error: $e")
    end
end
# HTTP.serve! returns an `HTTP.Server` object that we can close manually
close(server)
#= # start a blocking server
HTTP.listen() do http::HTTP.Stream
    @show http.message
    @show HTTP.header(http, "Content-Type")
    while !eof(http)
        println("body data: ", String(readavailable(http)))
    end
    HTTP.setstatus(http, 404)
    HTTP.setheader(http, "Foo-Header" => "bar")
    HTTP.startwrite(http)
    write(http, "response body")
    write(http, "more response body")
end
=#

server = WebsocketServer()

listen(server, :client) do ws
    listen(ws, :message) do message
        try
            comm = Meta.parse(message)
            println(comm)
            result = Base.eval(@__MODULE__, comm)
            send(ws, string(result))
        catch err
            @error err
            println(message)
            send(ws, "Could not run command")
        end
    end
end
function echo(val)
    return val
end
serve(server, 8080)