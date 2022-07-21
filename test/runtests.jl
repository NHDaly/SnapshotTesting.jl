using SnapshotTesting
using Test

@testset "SnapshotTesting.jl" begin
    @testset "snapshots" begin
        include("snapshots.jl")
    end
end
