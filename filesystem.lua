local fs = {}

local utils = dofile("utils.lua")

function fs.getPathSeperator()
    if os.host() == "windows" then
        return "\\"
    else
        return "/"
    end
end

function fs.exists(file)
    local ok, err, code = os.rename(file, file)
    if not ok then
        if code == 13 or code == 32 or code == 5 then
            -- Permission denied, but it exists
            return true, nil, nil
        end
        return false, err, code
   end
   return true, nil, nil
end

function fs.readLines(file)
    if not fs.exists(file) then return {} end

    local lines = {}
    for line in io.lines(file) do
        lines[#lines + 1] = line
    end

    return lines
end

function fs.parentPath(path)
    return string.match(path, "^(.+)[/\\]")
end

function fs.fileName(path)
    return string.match(path, "([^/\\]+)$")
end

function fs.rootName(path)
    return string.match(path, "^([^/\\]+)")
end

function fs.resolvePaths(paths, root)
    local correctedRoot = (utils.stringEndsWith(root, "/") and root) or (utils.stringEndsWith(root, "\\") and root) or (root .. "/")
    local resolved = {}

    for i, pattern in ipairs(paths) do
        if string.find(pattern, "^(%.[/\\])") == nil then
            resolved[#resolved + 1] = pattern
        else
            resolved[#resolved + 1] = correctedRoot .. string.sub(pattern, 3)
        end
    end

    return resolved
end

function fs.sanitize(path)
    local result, count = string.gsub(path, "([/\\]+)", fs.getPathSeperator())
    
    if utils.stringEndsWith(result, fs.getPathSeperator()) then
        result = result:sub(1, -2)
    end

    return result
end

return fs