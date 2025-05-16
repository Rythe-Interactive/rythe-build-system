local utils = {
    indent = ""
}

function utils.trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function utils.concatTables(lhs, rhs)
	for i=1, #rhs do
		lhs[#lhs + 1] = rhs[i]
	end
	return lhs
end

function utils.tableIsEmpty(t)
	return t == nil or next(t) == nil
end

function utils.stringEndsWith(str, suffix)
	return str:sub(-#suffix) == suffix
end

function utils.copyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		copy[key] = value
	end
	return copy
end

function utils.pushIndent()
    utils.indent = utils.indent .. "\t"
end

function utils.popIndent()
    utils.indent = utils.indent:sub(-1)
end

function utils.printIndented(msg)
    print(utils.indent .. msg)
end

function utils.printTable(name, table, recurse)
    utils.printIndented(name .. ":")

   utils. pushIndent()
        for key, value in pairs(table) do
            if type(value) == "table" then
                if recurse ~= nil and recurse then
                    utils.pushIndent()
                        utils.printTable(key, value, recurse)
                    utils.popIndent()
                else
                    utils.printIndented(key .. ": " .. "table")
                end
            elseif type(value) == "function" then
                utils.printIndented(key .. ": " .. "function")
            elseif type(value) == "boolean" then
                utils.printIndented(key .. ": " .. (value and "true" or "false"))
            else
                utils.printIndented(key .. ": " .. value)
            end
        end
    utils.popIndent()
end

return utils