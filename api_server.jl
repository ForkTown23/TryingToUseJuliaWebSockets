using CSV, SimpleWebsockets, HTTP, CurricularAnalytics, CurricularAnalyticsDiff, JSON, Sockets

big_curric = read_csv("./files/condensed.csv");

# this format is based off of the examples in the HTTP.jl Github respond
const ROUTER = HTTP.Router()

# functions for each of the things you can do
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
    HTTP.Response(200, "Simple Dummy Response - You want to remove a course normally")
end

# remove prereq normally
function rem_pre_norm(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to remove a prereq normally")
end

# add course institutional
function add_cou_inst(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to add a course institutionally")
end

# add prereq institutional
function add_pre_inst(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to add a prereq institutionally")
end

# remove_course_institutional
function rem_cou_inst(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to remove a course intitutionally")
end

# remove prereq institutional
function rem_pre_inst(req::HTTP.Request)
    HTTP.Response(200, "Simple Dummy Response - You want to remove a prereq institutionally")
end

# Register the routes
HTTP.register!(ROUTER, "POST", "/api/normal/add/course", add_cou_norm)
HTTP.register!(ROUTER, "POST", "/api/normal/add/prereq", add_pre_norm)
HTTP.register!(ROUTER, "POST", "/api/normal/remove/course", rem_cou_norm)
HTTP.register!(ROUTER, "POST", "/api/normal/remove/prereq", rem_pre_norm)
HTTP.register!(ROUTER, "POST", "/api/institutional/add/course", add_cou_inst)
HTTP.register!(ROUTER, "POST", "/api/institutional/add/prereq", add_pre_inst)
HTTP.register!(ROUTER, "POST", "/api/institutional/remove/course", rem_cou_inst)
HTTP.register!(ROUTER, "POST", "/api/institutional/remove/prereq", rem_pre_inst)

# Serve !
server = HTTP.serve!(ROUTER, Sockets.localhost, 8080)

#close(server)