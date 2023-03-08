using CurricularAnalytics
include("./api_methods.jl")

condensed = read_csv("./files/condensed2.csv")
println("gosh")
println("gosh")
println("gosh")
println("gosh")

res = add_course_inst_web("MATH 20A.5", 5.0, Dict("MATH 20A" => pre), Dict("MATH 20B" => pre), condensed, ["AN26SI", "AN26curriculum"])

res = add_course_inst_web("MATH 20B.5", 5.0, Dict("MATH 20B" => pre), Dict("MATH 20C" => pre), condensed, ["AN26SI", "AN26curriculum"])

println("dddddd-done")