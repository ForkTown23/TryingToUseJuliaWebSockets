using CSV
using SimpleWebsockets
using HTTP
using CurricularAnalytics
using CurricularAnalyticsDiff
using JSON

big_curric = read_csv("./files/condensed.csv")

function print_affected_plans_web(affected_plans)
    prev_major = "PL99"
    count = 0
    ret = ""
    for major in affected_plans
        if major != ""
            if major[1:4] != prev_major[1:4]
                prev_major = major
                ret = ret * "\n$(major[1:4]): $(major[5:end]), "
                #print("\n$(major[1:4]): $(major[5:end]), ")
                count += 1
            elseif major != prev_major # don't ask me why for some reason each plan code shows up multiple times
                prev_major = major
                ret = ret * "$(major[5:end]), "
                count += 1
            end
        end
    end
    ret = ret * "\n"
    return (ret, count)
end

function sanitize_add_course(param_string::Vector{SubString{String}})
    clean_params = param_string
    # TODO
    return clean_params
end

function sanitize_add_prereq(param_string::Vector{SubString{String}})
    # there are supposed to be two entries here.
    if length(param_string) != 2
        throw(ArgumentError("There's a weird number of courses here, we just need two."))
    end
    # they are in the format: "Target-Name=COURSE+CODE&Prereq-Name=COURSE+CODE"
    clean_params = Vector{String}()
    for pair in param_string
        course_w_code = split(pair, "=")[2]
        course_w_code = replace(course_w_code, "+" => " ")
        push!(clean_params, course_w_code)
    end
    return clean_params
end

function sanitize_remove_course(param_string::Vector{SubString{String}})
    # there is supposed to be one entry here
    if length(param_string) != 1
        throw(ArgumentError("There's a weird number of courses here, we just need one."))
    end
    # it should be in the format "Target-Name=COURSE+CODE"
    clean_params = Vector{String}()
    for pair in param_string
        course_w_code = split(pair, "=")[2]
        course_w_code = replace(course_w_code, "+" => " ")
        push!(clean_params, course_w_code)
    end
    return clean_params
end

function sanitize_remove_prereq(param_string::Vector{SubString{String}})
    # there are supposed to be two entries here.
    if length(param_string) != 2
        throw(ArgumentError("There's a weird number of courses here, we just need two."))
    end
    # they are in the format: "Target-Name=COURSE+CODE&Prereq-Name=COURSE+CODE"
    clean_params = Vector{String}()
    for pair in param_string
        course_w_code = split(pair, "=")[2]
        course_w_code = replace(course_w_code, "+" => " ")
        push!(clean_params, course_w_code)
    end
    return clean_params
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
        affected = ""
        method = split(request_strings[1], "=")[2]
        # this is going to be chained if-elses, julia has no native switch, and I don't want to add another package
        if (method == "add-course")
            response = "Alright! Let's add a course!"
            # sanitize for add course
            clean_params = sanitize_add_course(request_strings[2:end])
            # then call it TODO
            affected = ""
        elseif (method == "add-prereq")
            response = "Alright! Let's add a prereq!"
            # sanitize for add-prereq
            clean_params = sanitize_add_prereq(request_strings[2:end])
            # then call it TODO
            affected = add_prereq_institutional(big_curric, clean_params[1], clean_params[2])
            (affected, count) = print_affected_plans_web(affected)
            affected = affected * "Number of plans affected $count"
        elseif (method == "remove-course")
            response = "Alright! Let's remove a course!"
            # sanitize for remove prereq
            clean_params = sanitize_remove_course(request_strings[2:end])
            # then call it
            affected = delete_course_institutional(clean_params[1], big_curric)
            # collect the plans and print properly
            (affected, count) = print_affected_plans_web(affected)
            affected = affected * "Number of plans affected $count"
        elseif (method == "remove-prereq")
            response = "Alright! Let's remove a prereq!"
            #sanitize for remove prereq
            clean_params = sanitize_remove_prereq(request_strings[2:end])
            # then call it
            affected = delete_prerequisite_institutional(clean_params[1], clean_params[2], big_curric)
            (affected, count) = print_affected_plans_web(affected)
            affected = affected * "Number of plans affected $count"
        else
            throw(ArgumentError("Hey, I'm not sure what method you're trying to call. Please try again :)"))
        end
        return HTTP.Response("$response, \n $clean_params \n $affected")
    catch e
        println(e)
        return HTTP.Response(400, "Error: $e")
    end
end
# HTTP.serve! returns an `HTTP.Server` object that we can close manually
close(server)