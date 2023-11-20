
"""
    create_expectation_snapshot(f::Function, expected_dir, subpath)
    create_expectation_snapshot(expected_dir, subpath) do dir
        ...
    end

Run the provided function, which should write files to the `dir` it gets as an argument,
creating a snapshot of the current state of the code at the supplied path.
"""
function create_expectation_snapshot(func, expected_dir, subpath)
    snapshot_dir = joinpath(expected_dir, subpath)

    mkpath(snapshot_dir)

    func(snapshot_dir)
end

function test_snapshot(func, expected_dir, subpath; allow_additions = true, regenerate = false)
    if regenerate
        create_expectation_snapshot(func, expected_dir, subpath)
        return nothing
    end

    output_path = mktempdir()
    snapshot_dir = joinpath(output_path, subpath)

    # Run the user code on the newly created directory
    mkpath(snapshot_dir)
    func(snapshot_dir)

    # Test against the expected files
    expected_path = joinpath(expected_dir, subpath)
    @testset "$subpath" begin
        _recursive_diff_dirs(expected_path, snapshot_dir; allow_additions)
    end
end
# Diff all the files in the output directory against the expected directory
function _recursive_diff_dirs(expected_dir, new_dir; allow_additions)
    # Collect new files
    new_files = Set(String[])
    for (root, _, files) in walkdir(new_dir)
        for file in files
            subpath = _chopprefix(_chopprefix(file, new_dir), "/")
            push!(new_files, subpath)
        end
    end

    # Walk the expected files and make sure they are all present in the new directory
    for (root, _, files) in walkdir(expected_dir)
        for file in files
            expected_path = joinpath(root, file)
            expected_content = read(expected_path, String)
            subpath = _chopprefix(_chopprefix(expected_path, expected_dir), "/")
            @test subpath in new_files
            if !(subpath in new_files)
                @error("New snapshot is missing file `$subpath`. Expected contents:\n",
                        expected_content)
            else
                delete!(new_files, subpath)
                new_path = joinpath(new_dir, subpath)
                new_content = read(new_path, String)
                @test new_content == expected_content
                if new_content != expected_content
                    println("Found non-matching content in `$file`.")
                    display(DeepDiffs.deepdiff(expected_content, new_content))
                end
            end
        end
    end

    # Any remaining files were newly produced by the snapshot, and aren't part of the
    # expected content.
    if !allow_additions
        # Report test failures for the new files if requested
        if !isempty(new_files)
            @error("New snapshot contains unexpected files. If this is not an error in your
                case, pass `allow_additions = true`.")
            for path in new_files
                @test false  # report one test failure per unexpected file

                new_path = joinpath(new_dir, path)
                new_content = read(new_path, String)
                @error("File: `$path` contents:\n",
                        new_content)
            end
        end
    end
end


# Based on `chopprefix` from julia 1.8+
function _chopprefix(s::AbstractString, prefix::AbstractString)
    k = firstindex(s)
    i, j = iterate(s), iterate(prefix)
    while true
        j === nothing && i === nothing && return SubString(s, 1, 0) # s == prefix: empty result
        j === nothing && return @inbounds SubString(s, k) # ran out of prefix: success!
        i === nothing && return SubString(s) # ran out of source: failure
        i[1] == j[1] || return SubString(s) # mismatch: failure
        k = i[2]
        i, j = iterate(s, k), iterate(prefix, j[2])
    end
end
