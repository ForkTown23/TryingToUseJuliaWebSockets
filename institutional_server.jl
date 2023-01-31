using CSV
using SimpleWebsockets
using HTTP
using CurricularAnalytics
using CurricularAnalyticsDiff
using JSON

big_curric = read_csv("./files/condensed.csv")

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
html{ background-color: black;}
body{
font-family: 'Roboto', sans-serif;
font-size:15px;
-webkit-user-select: none;
  -khtml-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none; 
align-items: stretch;
overflow: visible;
}
h1{
color:rgb(18, 169, 154);
text-align:center
}
.wrap{
width:100%;
height: 100%;
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
    table{
        color: white
        border: 1px solid white
    }
    .shows-up{
        background-color: red
    }
    .no-show{
        background-color: green
    }
    .major{
        color: white;
    }
    th {
        color: white
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
    header = "<p class='helper-text'>This edit affects $count plans:</p>"
    block = split(ret, "\n")
    html_block = html_block * header
    table_tags = ["<table>", "</table>"]
    table_row_tags = ["<tr>", "</tr>"]
    table_header_tags = ["<th>", "</th>"]
    cell_tags = Dict("major" => "<td class=major>", "shows up" => "<td class=shows-up>", "no show" => "<td class=no-show>", "end" => "</td>")
    colleges = ["FI", "MU", "RE", "SI", "SN", "TH", "WA", "curriculum"]
    # assemble the header first
    html_block = html_block * table_tags[1] * table_row_tags[1] * table_header_tags[1] * "Major" * table_header_tags[2]
    for college in colleges
        html_block = html_block * table_header_tags[1] * college * table_header_tags[2]
    end
    html_block = html_block * table_row_tags[2]
    # Skip the first and last of the affected string because they are just new lines and they trip the rest of this up
    for affected_row in block[2:end-1]
        table_row = ""
        split_results = split(affected_row, ":")
        major = strip(split_results[1]) # remove whitespace
        plans = split(strip(split_results[2]), ",")
        table_row = table_row * table_row_tags[1] * cell_tags["major"] * major * cell_tags["end"]
        for college in colleges
            if college in plans
                table_row = table_row * cell_tags["shows up"] * cell_tags["end"]
            else
                table_row = table_row * cell_tags["no show"] * cell_tags["end"]
            end
        end
        html_block = html_block * table_row
    end
    return (ret, count, html_block)
end

function sanitize_add_course(param_string::Vector{SubString{String}})
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
    println(request_string)
    request_strings = split(request_string, "&")
    try
        response = ""
        clean_params = ""
        affected = ""
        html_resp = ""
        method = split(request_strings[1], "=")[2]
        # this is going to be chained if-elses, julia has no native switch, and I don't want to add another package
        if (method == "add-course")
            response = "Alright! Let's add a course!"
            # sanitize for add course
            clean_params = sanitize_add_course(request_strings[2:end])
            # then call it TODO
            affected = add_course_institutional(clean_params[1], big_curric, clean_params[2], clean_params[3], clean_params[4])
            (affected, count, html_resp) = print_affected_plans_web(affected)
            affected = affected * "Number of plans affected $count" #oop
        elseif (method == "add-prereq")
            response = "Alright! Let's add a prereq!"
            # sanitize for add-prereq
            clean_params = sanitize_add_prereq(request_strings[2:end])
            # then call it TODO
            affected = add_prereq_institutional(big_curric, clean_params[1], clean_params[2])
            (affected, count, html_resp) = print_affected_plans_web(affected)
            affected = affected * "Number of plans affected $count"
        elseif (method == "remove-course")
            response = "Alright! Let's remove a course!"
            # sanitize for remove prereq
            clean_params = sanitize_remove_course(request_strings[2:end])
            # then call it
            affected = delete_course_institutional(clean_params[1], big_curric)
            # collect the plans and print properly
            (affected, count, html_resp) = print_affected_plans_web(affected)
            affected = affected * "Number of plans affected $count"
        elseif (method == "remove-prereq")
            response = "Alright! Let's remove a prereq!"
            #sanitize for remove prereq
            clean_params = sanitize_remove_prereq(request_strings[2:end])
            # then call it
            affected = delete_prerequisite_institutional(clean_params[1], clean_params[2], big_curric)
            (affected, count, html_resp) = print_affected_plans_web(affected)
            affected = res[1] * "Number of plans affected $(res[2])"
        else
            throw(ArgumentError("Hey, I'm not sure what method you're trying to call. Please try again :)"))
        end
        # if all is well so far, respond with html
        resp = institutional_response_first_half * html_resp * institutional_response_second_half
        println(resp)
        return HTTP.Response("$resp") #="$response, \n $clean_params \n $affected"=#
    catch e
        showerror(stdout, e)
        display(stacktrace(catch_backtrace()))
        return HTTP.Response(400, "Error: $e")
    end
end
# HTTP.serve! returns an `HTTP.Server` object that we can close manually
close(server)