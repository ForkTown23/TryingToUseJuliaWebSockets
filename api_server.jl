using CSV, SimpleWebsockets, HTTP, CurricularAnalytics, CurricularAnalyticsDiff, JSON, Sockets

# UCSD curriculum
big_curric = read_csv("./files/condensed.csv");

# html stuff
institutional_response_first_half = "<!DOCTYPE html>
<html lang='en'>
    <head>
        <meta charset='utf-8'>
        <title>Institutional What If Response</title>
        <style>
        body {
    font-family: sans-serif;
    height: 100vh;
    padding: 0;
    margin: 0;
    display: flex;
    justify-content: center;
    align-items: center;
}
input {
    margin: 4px 0;
}
@import url(https://fonts.googleapis.com/css?family=Roboto);
html{ background-color:black}
body{
font-family: 'Roboto', sans-serif;
font-size:15px;
-webkit-user-select: none;
  -khtml-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none; 
align-items: stretch;
overflow:visible;
}
h1{
color:rgb(18, 169, 154);
text-align:center
}
.wrap{
width:100%;
margin:0 auto;
background-color:black;
}
.collapse {
background-color: rgba(255,255,255,0);
border-bottom: 1px solid #eee;
cursor: pointer;
color: #fff;
padding: 10px;
margin:0px;
max-height:40px;
overflow:hidden;
transition: all 0.4s;
}
.collapse * {
-webkit-box-sizing: border-box;
-moz-box-sizing: border-box;
box-sizing: border-box;

}
.collapse.active {
background-color: rgba(255,255,255,0.9);
box-shadow: 0 8px 17px 0 rgba(0, 0, 0, 0.2);
z-index: 200;
color:#444;
max-height:3000px;
padding:10px 20px;
margin: 10px -10px;
transition: all 0.2s,max-height 4.8s;
}
.collapse h2 {
font-size: 18px;
line-height: 20px;
position:relative
}
.slide{
box-shadow:none !important;
margin:0px !important;
padding:10px !important
}
.transparent{
background-color: rgba(255,255,255,0) !important;
color:#fff !important;
box-shadow:none !important;
margin:0px !important;
padding:10px !important
}
.collapse h2::after{
content: ' + ';
  text-align:center;
  position:absolute;
  width:15px;
  height:15px;
  border:1px solid #ccc;
  border-radius:50%;
  font-size:12px;
  line-height:15px;
  opacity:0.5;
  right:0;
  top:0;
  }
  .collapse:hover h2::after{
  opacity:1
  }
  
  .collapse.active h2::after{
  content: ' - ';
    }
    .helper-text{
    color: #fff
    }
    form{
    display:table;
    }
    .form-row{
    display:table-row;
    }
    label{
    display:table-cell;
    }
    .input-text{
    margin:1em;
    display:table-cell;
    }
    </style>
            <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.6.1/jquery.min.js'></script>
        </head>
        <body>
            <div class='wrap'>
                <h1>Query Results!</h1>"

institutional_response_second_half = "</div>
<script>
// Script the makes sure only one option is open at a time.
// mostly for flavor :)
\$('.collapse-header').on('click',function(e){
  e.preventDefault();
  \$('.collapse').not(\$(this).parent()).removeClass('active')
  \$(this).parent().toggleClass('active');
});
/*
\$('h2').on('click', function(e){
  e.preventDefault()
});*/
</script> 
</body>
</html>"

#------------------------------------------------------------------------------------
# this format is based off of the examples in the HTTP.jl Github repo
const ROUTER = HTTP.Router()
#------------------------------------------------------------------------------------
# print affected plans web helper font
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
    html_block = ""
    collapse_tag = "<div class='collapse'>"
    collapse_header_tag = "<div class='collapse-header'>"
    div_close_tag = "</div>"
    header = "<p class='helper-text'>This edit affects $count plans:</p>"
    html_block = html_block * header
    block = split(ret, "\n")
    # Skip the first and last because they are just new lines and they trip the rest of this up
    for affected_row in block[2:end-1]
        split_results = split(affected_row, ":")
        block_header = split_results[1]
        block_content = split_results[2]
        major_code_header = "<h2>$block_header</h2>"
        results_p = "<p>$block_content</p>"
        div_block = collapse_tag * collapse_header_tag * major_code_header * div_close_tag * results_p * div_close_tag
        html_block = html_block * div_block
    end
    return (ret, count, html_block)
end
#------------------------------------------------------------------------------------
# parameter sanitizer functions
# TODO the normal ones
function sanitize_add_course_institutional(param_string::Vector{SubString{String}})
    # there are supposed to be 8 entries here
    if length(param_string) != 8
        throw(ArgumentError("There's a weird number of courses here, we need eight."))
    end
    # they are in the format: ["Target-Name=MATH+20B.5", "Target-Hours=5", "Target-Prereq1=MATH+20B", "Target-Prereq2=MATH+20A", "Target-Prereq3=MATH+4C", "Target-Dep1=MATH+108", "Target-Dep2=MATH+109", "Target-Dep3=MATH+20E"] 
    clean_params = Vector{String}()
    for pair in param_string
        course_w_code = split(pair, "=")[2]
        course_w_code = replace(course_w_code, "+" => " ")
        push!(clean_params, course_w_code)
    end
    # there's a few extra things to do here
    # 1) turn things into the dict format
    # 2) remove the empty ones
    # instead i'm just adding the non-empty ones
    prereqs = Dict()
    for prereq in clean_params[3:5]
        if prereq != ""
            prereqs[prereq] = pre
        end
    end
    deps = Dict()
    for dep in clean_params[6:8]
        if dep != ""
            deps[dep] = pre
        end
    end
    cleaner_params = []
    push!(cleaner_params, clean_params[1])
    push!(cleaner_params, parse(Float64, clean_params[2]))
    push!(cleaner_params, prereqs)
    push!(cleaner_params, deps)
    return cleaner_params
end

function sanitize_add_prereq_institutional(param_string::Vector{SubString{String}})
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

function sanitize_remove_course_institutional(param_string::Vector{SubString{String}})
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

function sanitize_remove_prereq_institutional(param_string::Vector{SubString{String}})
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
#------------------------------------------------------------------------------------------
# functions for each of the things you can do
# TODO add the normal functions
# add course normally
function add_cou_norm(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to add a course normally")
end

# add prereq normally
function add_pre_norm(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to add a prereq normally")
end

# remove course normally
function rem_cou_norm(req::HTTP.Request)
    #println("showing req")
    #@show req
    #println("showing req.method")
    #@show req.method
    #println("showing header content type")
    #@show HTTP.header(req, "Content-Type")
    #println("showing the parsed content")
    #bod = HTTP.parse_multipart_form(req)
    #println("showing a string version of the parsing")

    # the straight up string version seems to work fine. This is a very ugly method, though.
    bod = String(req.body)
    println("full bod")
    println(bod)
    dirty_params = split(bod, "-----------------------------")
    println("first dirty param")
    println(dirty_params[1])
    println("second dirty param")
    println(dirty_params[2])
    println("third dirty param")
    println(dirty_params[3])

    csv = split(dirty_params[2], "\n")[5:end-3]
    open("newfile.csv", "w") do file
        for row in csv
            write(file, row)
            write(file, "\n")
        end
    end
    # double check the type, could be degree plan, or nothing at all
    curr = read_csv("./newfile.csv")
    println("curriculum!")
    println(curr)
    HTTP.Response(200, "Simple Dummy Response - You want to remove a course normally, \nhere is the longest path $(longest_paths(curr.curriculum))")
end

# remove prereq normally
function rem_pre_norm(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to remove a prereq normally")
end

# add course institutional
function add_cou_inst(req::HTTP.Request)
    request_string = String(req.body)
    request_strings = split(request_string, "&")
    try
        clean_params = ""
        affected = ""
        html_resp = ""

        # clean the parameters
        clean_params = sanitize_add_course_institutional(request_strings[2:end])
        # add the course and analyze
        affected = add_course_institutional(clean_params[1], big_curric, clean_params[2], clean_params[3], clean_params[4])
        # clean results and compose response
        (affected, count, html_resp) = print_affected_plans_web(affected)
        affected = affected * "Number of plans affected: $count"
        resp = institutional_response_first_half * html_resp * institutional_response_second_half
        println(resp)
        return HTTP.Response(200, "$resp")
    catch e
        showerror(stdout, e)
        display(stacktrace(catch_backtrace()))
        return HTTP.Response(400, "Error: $e")
    end
    #HTTP.Response(200, "Simple Dummy Response - You want to add a course institutionally")
end

# add prereq institutional
function add_pre_inst(req::HTTP.Request)
    request_string = String(req.body)
    request_strings = split(request_string, "&")
    try
        clean_params = ""
        affected = ""
        html_resp = ""

        # clean params
        clean_params = sanitize_add_prereq_institutional(request_strings[2:end])
        # add the prereq and analyze
        affected = add_prereq_institutional(big_curric, clean_params[1], clean_params[2])
        # clean the results for the web and compose the repsonse
        (affected, count, html_resp) = print_affected_plans_web(affected)
        affected = affected * "Number of plans affected: $count"
        resp = institutional_response_first_half * html_resp * institutional_response_second_half
        println(resp)
        return HTTP.Response(200, "$resp")
    catch e
        showerror(stdout, e)
        display(stacktrace(catch_backtrace()))
        return HTTP.Response(400, "Error: $e")
    end
    #HTTP.Response(200, "Simple Dummy Response - You want to add a prereq institutionally")
end

# remove_course_institutional
function rem_cou_inst(req::HTTP.Request)
    request_string = String(req.body)
    request_strings = split(request_string, "&")
    try
        clean_params = ""
        affected = ""
        html_resp = ""

        # clean params
        clean_params = sanitize_remove_course_institutional(request_strings[2:end])
        # delete the course and alayze
        affected = delete_course_institutional(clean_params[1], big_curric)
        # clean the results specifically for the webkit
        (affected, count, html_resp) = print_affected_plans_web(affected)
        affected = affected * "Number of plans affected $count"
        # compose the response
        resp = institutional_response_first_half * html_resp * institutional_response_second_half
        println(resp)
        # respond
        return HTTP.Response(200, "$resp") #="$response, \n $clean_params \n $affected"=#
    catch e
        showerror(stdout, e)
        display(stacktrace(catch_backtrace()))
        return HTTP.Response(400, "Error: $e")
    end
    #HTTP.Response(200, "Simple Dummy Response - You want to remove a course intitutionally")
end

# remove prereq institutional
function rem_pre_inst(req::HTTP.Request)
    request_string = String(req.body)
    request_strings = split(request_string, "&")
    try
        clean_params = ""
        affected = ""
        html_resp = ""

        # clean params
        clean_params = sanitize_remove_prereq_institutional(request_strings[2:end])
        # remove the prereq and analyze
        affected = delete_prerequisite_institutional(clean_params[1], clean_params[2], big_curric)
        # compose the response
        (affected, count, html_resp) = print_affected_plans_web(affected)
        affected = affected * "Number of plans affected: $count"
        resp = institutional_response_first_half * html_resp * institutional_response_second_half
        println(resp)
        # respond
        return HTTP.Response(200, "$resp")
    catch e
        showerror(stdout, e)
        display(stacktrace(catch_backtrace()))
        return HTTP.Response(400, "Error: $e")
    end
    #HTTP.Response(200, "Simple Dummy Response - You want to remove a prereq institutionally")
end
#------------------------------------------------------------------------------
# Register the routes
HTTP.register!(ROUTER, "POST", "/api/normal/add/course", add_cou_norm)
HTTP.register!(ROUTER, "POST", "/api/normal/add/prereq", add_pre_norm)
HTTP.register!(ROUTER, "POST", "/api/normal/remove/course", rem_cou_norm)
HTTP.register!(ROUTER, "POST", "/api/normal/remove/prereq", rem_pre_norm)
HTTP.register!(ROUTER, "POST", "/api/institutional/add/course", add_cou_inst)
HTTP.register!(ROUTER, "POST", "/api/institutional/add/prereq", add_pre_inst)
HTTP.register!(ROUTER, "POST", "/api/institutional/remove/course", rem_cou_inst)
HTTP.register!(ROUTER, "POST", "/api/institutional/remove/prereq", rem_pre_inst)
#--------------------------------------------------------------------------------
# Serve !
server = HTTP.serve!(ROUTER, Sockets.localhost, 8080)
