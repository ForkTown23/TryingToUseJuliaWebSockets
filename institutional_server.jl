using CSV
using SimpleWebsockets
using HTTP
using CurricularAnalytics
using CurricularAnalyticsDiff
using JSON

function sanitize_add_course(param_string::Vector{SubString{String}})
    clean_params = param_string
    return clean_params
end

function sanitize_add_prereq(param_string::Vector{SubString{String}})
    clean_params = param_string

    return clean_params
end

function sanitize_remove_course(param_string::Vector{SubString{String}})
    clean_params = param_string
    return clean_params
end

function sanitize_remove_prereq(param_string::Vector{SubString{String}})
    clean_params = param_string
    return clean_params
end

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
        clean_params = ""
        method = split(request_strings[1], "=")[2]
        # this is going to be chained if-elses, julia has no native switch, and I don't want to add another package
        if (method == "add-course")
            # do the add course stuff
            response = "Alright! Let's add a course!"
            clean_params = sanitize_add_course(request_strings[2:end])
        elseif (method == "add-prereq")
            response = "Alright! Let's add a prereq!"
            # sanitize for add-prereq
            clean_params = sanitize_add_prereq(request_strings[2:end])
            println(typeof(clean_params))
        elseif (method == "remove-course")
            response = "Alright! Let's remove a course!"
            clean_params = sanitize_remove_course(request_strings[2:end])
        elseif (method == "remove-prereq")
            response = "Alright! Let's remove a prereq!"
            clean_params = sanitize_remove_prereq(request_strings[2:end])
        else
            throw(ArgumentError("Hey, I'm not sure what method you're trying to call. Please try again :)"))
        end
        return HTTP.Response("$response, \n $clean_params")
    catch e
        println(e)
        return HTTP.Response(400, "Error: $e")
    end
end
# HTTP.serve! returns an `HTTP.Server` object that we can close manually
close(server)