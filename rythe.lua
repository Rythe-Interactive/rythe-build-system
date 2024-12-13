include("_preload.lua")

premake.rythe = {
    configuration = {
        RELEASE = 1,
        DEVELOPMENT = 2,
        DEBUG = 3
    },
    configurationVariants = {
        DEFAULT = 1,
        ASAN = 2,
        PROFILING = 3
    },
    loadedProjects = {},
    buildSettings = {
        architecture = "x86_64",
        cppVersion = "C++20"
    }
}

premake.rythe.buildSettings.toolsets = {
    [premake.rythe.configuration.RELEASE] = { [premake.rythe.configurationVariants.DEFAULT] = "clang", [premake.rythe.configurationVariants.ASAN] = "msc", [premake.rythe.configurationVariants.PROFILING] = "clang" },
    [premake.rythe.configuration.DEVELOPMENT] = { [premake.rythe.configurationVariants.DEFAULT] = "clang", [premake.rythe.configurationVariants.ASAN] = "msc", [premake.rythe.configurationVariants.PROFILING] = "clang" },
    [premake.rythe.configuration.DEBUG] =  { [premake.rythe.configurationVariants.DEFAULT] = "clang", [premake.rythe.configurationVariants.ASAN] = "msc", [premake.rythe.configurationVariants.PROFILING] = "clang" }
}

premake.rythe.configurationValidationLevels = {
    [premake.rythe.configuration.RELEASE] = { [premake.rythe.configurationVariants.DEFAULT] = "0", [premake.rythe.configurationVariants.ASAN] = "0", [premake.rythe.configurationVariants.PROFILING] = "0" },
    [premake.rythe.configuration.DEVELOPMENT] = { [premake.rythe.configurationVariants.DEFAULT] = "2", [premake.rythe.configurationVariants.ASAN] = "2", [premake.rythe.configurationVariants.PROFILING] = "2" },
    [premake.rythe.configuration.DEBUG] =  { [premake.rythe.configurationVariants.DEFAULT] = "3", [premake.rythe.configurationVariants.ASAN] = "3", [premake.rythe.configurationVariants.PROFILING] = "3" }
}

local rythe = premake.rythe

local projects = dofile("projects.lua")

function rythe.architecture(architecture)
    rythe.buildSettings.architecture = architecture
end

function rythe.toolset(toolset)
    for i, config in pairs(rythe.configuration) do
        for j, variant in pairs(rythe.configurationVariants) do
            rythe.buildSettings.toolsets[config][variant] = toolset
        end
    end
end

function rythe.cppVersion(cppVersion)
    rythe.buildSettings.cppVersion = cppVersion
end

function rythe.overrideValidationLevel(config, variant, level)
    rythe.configurationValidationLevels[config][variant] = tostring(level)
end

function rythe.overrideToolset(config, variant, toolset)
    rythe.buildSettings.toolsets[config][variant] = toolset
end

function rythe.configName(config)
    local configNames = { 
        [rythe.configuration.RELEASE] = "Release",
        [rythe.configuration.DEVELOPMENT] = "Development",
        [rythe.configuration.DEBUG] = "Debug",
    }

    return configNames[config]
end

function rythe.targetSuffix(config)
    local configSuffix = { 
        [rythe.configuration.RELEASE] = "",
        [rythe.configuration.DEVELOPMENT] = "-dev",
        [rythe.configuration.DEBUG] = "-debug"        
    }

    return configSuffix[config]
end

function rythe.targetVariantSuffix(variant)
    local variantSuffix = { 
        [rythe.configurationVariants.DEFAULT] = "",
        [rythe.configurationVariants.ASAN] = "-asan",
        [rythe.configurationVariants.PROFILING] = "-profiling"        
    }

    return variantSuffix[variant]
end

function rythe.configure(workspaces)
    for i, wspc in ipairs(workspaces) do
        workspace(wspc.name)
            location(wspc.location)
            configurations(wspc.configurations)
        
        os.copyfile(_WORKING_DIR .. "/.runsettings", _WORKING_DIR .. "/" .. wspc.location .. "/.runsettings")
    end

    projects.addBuiltInProjects()
    projects.scan("./")
    projects.resolveAllDeps()
    projects.sumbitAll()
end

return rythe
