local fs = dofile("filesystem.lua")
local ctx = dofile("context.lua")

local rythe = premake.rythe
local buildSettings = rythe.buildSettings
local utils = rythe.utils

local projects = {}

-- ============================================================================================================================================================================================================
-- =============================================================================== PROJECT STRUCTURE DEFINITION ===============================================================================================
-- ============================================================================================================================================================================================================

--  Field name                          | Default value                 | Description
-- ============================================================================================================================================================================================================
--  init                                | nil                           | Initialization function, this allows you to dynamically change project fields upon project load based on the workspace context
--  alias                               | <Project name>                | Alias for the project name
--  namespace                           | ""                            | Project namespace, also used for folder structures
--  types                               | <Based on folder structure>   | Target types this projet uses, valid values: "application", "module", "editor", "library", "header-only", "util", "test"
--  additional_types                    | [empty]                       | Extra target types to add to the project, can be used if you don't want to override the default project types
--  dependencies                        | [empty]                       | Project dependency definitions, format: [(optional)<public|private>(default <private>)] [path][(optional):<type>(default <library>)]
--  fast_up_to_date_check               | true                          | Enable or disable Visual Studio check if project outputs are already up to date (handy to turn off on util projects)
--  warning_level                       | "High"                        | Compiler warning level to enable, valid values: "Off", "Default", "Extra", "High", "Everything"
--  warnings_as_errors                  | true                          | Treat warnings as errors
--  additional_warnings                 | nil                           | List of additional warnings to enable, for Visual Studio this needs to be the warning number instead of the name
--  exclude_warnings                    | nil                           | List of warnings to explicitly disable, for Visual Studio this needs to be the warning number instead of the name
--  disable_exceptions                  | true                          | Disable exceptions
--  floating_point_config               | "Default"                     | Floating point configuration for the compiler to use, valid values: "Default", "Fast", "Strict", "None"
--  vector_extensions                   | nil                           | Which vector extension to enable, see: https://premake.github.io/docs/vectorextensions/
--  isa_extensions                      | nil                           | see: https://premake.github.io/docs/isaextensions/
--  defines                             | [empty]                       | Additional defines on top of the default ones Rythe will add (PROJECT_NAME, PROJECT_FULL_NAME, PROJECT_NAMESPACE)
--  files                               | ["./**"]                      | File filter patterns to find source files with
--  exclude_files                       | nil                           | Exclude patterns to exclude source files with
--  additional_include_dirs             | [empty]                       | Additional include dirs for #include ""
--  additional_external_include_dirs    | [empty]                       | Additional external include dirs for #include <> on top of the ones Rythe will auto detect from dependencies
--  additional_link_targets             | [empty]                       | Additional prebuilt libraries to link.
--  pre_build                           | nil                           | Prebuild command
--  post_build                          | nil                           | Postbuild command
--  pre_link                            | nil                           | Prelink command
--  multi_core_compilation              | true                          | Allow project to be compiled in parallel
--  link_time_optimization              | true                          | Enable LTO
--  pch_enabled                         | false                         | Enable precompiled headers
--  pch_file_name                       | "pch"                         | File name for pch header and pch source files (e.g. pch.hpp and pch.cpp will have the name: "pch")
--  debug_args                          | nil                           | List of arguments to provide to the executable while debugging.

local function folderToProjectType(projectFolder)
    if projectFolder == "applications" then
        return "application"
    elseif projectFolder == "modules" then
        return "module"
    elseif projectFolder == "libraries" then
        return "library"
    elseif projectFolder == "utils" then
        return "util"
    end

    return projectFolder
end

local function isValidProjectType(projectType)
    if projectType == "util" then
        return true
    elseif projectType == "application" then
        return true
    elseif projectType == "module" then
        return true
    elseif projectType == "editor" then
        return true
    elseif projectType == "library" or projectType == "header-only" then
        return true
    elseif projectType == "test" then
        return true
    end

    return false
end

local function findProjectRoot(projectPath)
    local rootName = fs.rootName(projectPath)
    local projectType = folderToProjectType(rootName)

    local rootNameLength = string.len(rootName) + 2
    local remainingPath = string.sub(projectPath, rootNameLength)

    while (isValidProjectType(projectType) ~= true) do
        
        if(remainingPath == "") then
            return projectPath, ""
        end

        rootName = fs.rootName(remainingPath)
        rootNameLength = string.len(rootName) + 2
        projectType = folderToProjectType(rootName)
        remainingPath = string.sub(remainingPath, rootNameLength)
    end

    local rootPath = string.sub(projectPath, 0, string.len(projectPath) - string.len(remainingPath))

    return rootPath, projectType
end

local function find(projectPath)
    local projectName = fs.fileName(projectPath)
    local rootPath, projectType = findProjectRoot(projectPath)
    local group = fs.parentPath(projectPath)

    local rootPathLength = string.len(rootPath) + 1
    if group ~= nil and string.len(group) > rootPathLength then
        group = string.sub(group, rootPathLength)
    else
        group = ""
    end

    local projectFile = projectPath .. "/.rythe_project"
    if not fs.exists(projectFile) then
        projectFile = nil
    end

    local thirdPartyFile = projectPath .. "/.rythe_third_party"
    if not fs.exists(thirdPartyFile) then
        thirdPartyFile = nil
    end

    return projectFile, thirdPartyFile, group, projectName, projectType
end

local function getProjectId(group, projectName)
    return group == "" and projectName or group .. "/" .. projectName
end

local function getDepAssemblyAndScope(dependency)
    local scope = string.match(dependency, "([^%s]+[%s]+)")
    local assemblyId = dependency
    
    if scope ~= "" and scope ~= nil then
        assemblyId = string.sub(dependency, string.len(scope) + 1)
        
        scope = string.gsub(scope, "%s+", "")
        if scope ~= "public" and scope ~= "private" then
            return nil, nil
        end

    else
        scope = "private"
    end

    return assemblyId, scope
end

local function isThirdPartyProject(projectId)
    return string.find(projectId, "^(third_party)") ~= nil
end

local function findAssembly(assemblyId)
    local projectId = string.match(assemblyId, "^([^:]+)")
    local projectType = string.sub(assemblyId, string.len(projectId) + 2)
    local project = rythe.loadedProjects[projectId]

    if projectType == "" then        
        if project == nil then
            return nil, projectId, nil
        else
            return project, projectId, project.types[1]
        end
    end

    return project, projectId, projectType
end

local function kindName(projectType)
    if projectType == "module" then
        return ctx.linkTarget()
    elseif projectType == "test" then
        return "ConsoleApp"
    elseif projectType == "editor" then
        return "SharedLib"
    elseif projectType == "application" then
        return "ConsoleApp"
    elseif projectType == "library" then
        return "StaticLib"
    elseif projectType == "header-only" then
        return "SharedItems"
    elseif projectType == "util" then
        return "Utility"
    end
    assert(false, "Unknown project type: \"" .. projectType .. "\"")
end

local function projectTypeGroupPrefix(projectType)
    if projectType == "util" then
        return "1 - utils/"
    elseif projectType == "application" then
        return "2 - applications/"
    elseif projectType == "module" then
        return "3 - modules/"
    elseif projectType == "editor" then
        return "4 - editor/"
    elseif projectType == "library" or projectType == "header-only" then
        return "5 - libraries/"
    elseif projectType == "test" then
        return "6 - tests/"
    end

    assert(false, "Unknown project type: \"" .. projectType .. "\"")
end

local function projectNameSuffix(projectType)
    if projectType == "module" then
        return "-module"
    elseif projectType == "test" then
        return "-test"
    elseif projectType == "application" then
        return "-application"
    elseif projectType == "editor" then
        return "-editor"
    end

    return ""
end

local function projectTypeFilesDir(location, projectType, namespace)
    if projectType == "test" then
        return location .. "/tests/"
    elseif projectType == "editor" then
        return location .. "/editor/"
    end

    local namespaceSrcDir = location .. "/src/"

    if namespace ~= "" then
        namespaceSrcDir = namespaceSrcDir .. namespace .. "/"
    end

    if not os.isdir(namespaceSrcDir) then
        return location .. "/"
    end

    return namespaceSrcDir
end

local function isProjectTypeMainType(projectType)
    if projectType == "test" then
        return false
    elseif projectType == "editor" then
        return false
    end

    return true
end

local function loadProject(projectId, project, name, projectType)
    if project.alias == nil then
        project.alias = name
    end

    if project.namespace == nil then
        project.namespace = ""
    end

    if project.types == nil then
        project.types = { projectType }
    else
        project.types[1] = projectType
    end

    if project.fast_up_to_date_check == nil then
        project.fast_up_to_date_check = true
    end

    if not utils.tableIsEmpty(project.additional_types) then
        project.types = utils.concatTables(project.types, project.additional_types)
    end

    if project.warning_level == nil then
        project.warning_level = "High"
    end

    if project.warnings_as_errors == nil then
        project.warnings_as_errors = true
    end

    if project.multi_core_compilation == nil then
        project.multi_core_compilation = true
    end

    if project.link_time_optimization == nil then
        project.link_time_optimization = true
    end

    if project.disable_exceptions == nil then
        project.disable_exceptions = true
    end

    if project.floating_point_config == nil then
        project.floating_point_config = "Default"
    end

    if project.pch_enabled == nil then
        project.pch_enabled = false
    end

    if project.pch_file_name == nil then
        if project.pch_enabled then
            project.pch_file_name = "pch"
        end
    else
        project.pch_enabled = true
    end

    if utils.tableIsEmpty(project.defines) then
        project.defines = { "PROJECT_NAME=" .. project.alias, "PROJECT_FULL_NAME=" .. project.name, "PROJECT_NAMESPACE=" .. project.namespace }
    else
        project.defines[#project.defines +1 ] = "PROJECT_NAME=" .. project.alias
        project.defines[#project.defines +1 ] = "PROJECT_FULL_NAME=" .. project.name
        project.defines[#project.defines +1 ] = "PROJECT_NAMESPACE=" .. project.namespace
    end

    if project.files == nil then -- files can be an empty table if no files need to be loaded
        project.files = { "./**" }
    end

    rythe.loadedProjects[projectId] = project

    return project
end

function projects.load(project)
    local projectFile, thirdPartyFile, group, name, projectType = find(project.location)
    local projectId = getProjectId(group, name)
    
    if rythe.loadedProjects[projectId] ~= nil then
        return rythe.loadedProjects[projectId]
    end

    if projectFile ~= nil then
        local projectPath = project.location
        project = dofile(projectFile)
        project.location = projectPath
    end

    if thirdPartyFile ~= nil then
        local thirdParties = dofile(thirdPartyFile)

        for i, thirdParty in ipairs(thirdParties) do
            thirdParty.src = thirdPartyFile

            if thirdParty.init ~= nil then
                ctx.project_location = third_party.location
                thirdParty = thirdParty:init(ctx)
            end
            
            if thirdParty == nil then
                utils.printIndented("Could not initialize a third party dependency of project \"" .. group .. "/" .. name .. "\"")
                return nil
            end

            local thirdPartyType = "library"

            if not utils.tableIsEmpty(thirdParty.types) then
                thirdPartyType = thirdParty.types[1]
            end

            local thirdPartyId = getProjectId(thirdParty.group, thirdParty.name)

            if not isThirdPartyProject(thirdPartyId) then
                thirdParty.group = "third_party/" .. thirdParty.group
                thirdPartyId = getProjectId(thirdParty.group, thirdParty.name)
            end

            if thirdParty.location == nil then
                thirdParty.location = project.location .. "/third_party/" .. thirdParty.name
            end

            thirdParty = loadProject(thirdPartyId, thirdParty, thirdParty.name, thirdPartyType)
        end
    end

    project.group = group
    project.name = name
    project.src = projectFile
    if project.init ~= nil then
        ctx.project_location = project.location
        project = project:init(ctx)
    end

    if not utils.tableIsEmpty(project.types) then
        projectType = project.types[1]
    end

    return loadProject(projectId, project, name, projectType)
end

local function appendTargetSuffixes(linkTargets, config, variant)
    local targetSuffix = rythe.targetSuffix(config)
    local variantSuffix = rythe.targetVariantSuffix(variant)
    local copy = {}
    for i, target in ipairs(linkTargets) do
        copy[i] = target .. variantSuffix .. targetSuffix
    end

    return copy
end

local function getConfigFilter(config)
    local configFilters = { 
        [rythe.configuration.RELEASE] = "configurations:Release*",
        [rythe.configuration.DEVELOPMENT] = "configurations:Development*",
        [rythe.configuration.DEBUG] = "configurations:Debug*"
    }

    return configFilters[config]
end

local function setupRelease()
    filter(getConfigFilter(rythe.configuration.RELEASE))
        defines { "NDEBUG" }
        optimize("Full")
end

local function setupDevelopment()
    filter(getConfigFilter(rythe.configuration.DEVELOPMENT))
        defines { "DEBUG" }
        optimize("Debug")
        inlining("Explicit")
        symbols("On")
end

local function setupDebug()
    filter(getConfigFilter(rythe.configuration.DEBUG))
        defines { "DEBUG" }
        optimize("Debug")
        symbols("On")
end

local function setupDefault(config, linkTargets)
    filter { "configurations:not *-asan", "configurations:not *-profiling", getConfigFilter(config) }
        defines { "RYTHE_VALIDATION_LEVEL=" .. rythe.configurationValidationLevels[config][rythe.configurationVariants.DEFAULT]  }
        links(appendTargetSuffixes(linkTargets, config, rythe.configurationVariants.DEFAULT))
        targetsuffix(rythe.targetVariantSuffix(rythe.configurationVariants.DEFAULT) .. rythe.targetSuffix(config))
        toolset(buildSettings.toolsets[config][rythe.configurationVariants.DEFAULT])
end

local function setupAsan(config, linkTargets)
    filter("configurations:*-asan")
        sanitize("Address")
        flags("NoIncrementalLink")
        editandcontinue("Off")
        defines { "_DISABLE_VECTOR_ANNOTATION", "_DISABLE_STRING_ANNOTATION" }

    filter { "configurations:*-asan", getConfigFilter(config) }
        defines { "RYTHE_VALIDATION_LEVEL=" .. rythe.configurationValidationLevels[config][rythe.configurationVariants.ASAN]  }
        links(appendTargetSuffixes(linkTargets, config, rythe.configurationVariants.ASAN))
        targetsuffix(rythe.targetVariantSuffix(rythe.configurationVariants.ASAN) .. rythe.targetSuffix(config))
        toolset(buildSettings.toolsets[config][rythe.configurationVariants.ASAN])
end

local function setupProfiling(config, linkTargets)
    filter("configurations:*-profiling")
        defines {"RYTHE_PROFILING_ENABLED"}
        
    filter { "configurations:*-profiling", getConfigFilter(config) }
        defines { "RYTHE_VALIDATION_LEVEL=" .. rythe.configurationValidationLevels[config][rythe.configurationVariants.PROFILING]  }
        links(appendTargetSuffixes(linkTargets, config, rythe.configurationVariants.PROFILING))
        targetsuffix(rythe.targetVariantSuffix(rythe.configurationVariants.PROFILING) .. rythe.targetSuffix(config))
        toolset(buildSettings.toolsets[config][rythe.configurationVariants.PROFILING])
end

local function getDepsRecursive(project, projectType)
    local deps = project.dependencies
    
    if deps == nil then
        deps = {}
    end

    local copy = utils.copyTable(deps)

    if projectType == "test" then
        local containsCatch = false

        for i, dep in ipairs(copy) do
            if string.match(dep, "third_party/catch2") then
                containsCatch = true
            end
        end

        if containsCatch == false then
            copy[#copy + 1] = "third_party/catch2"
        end
    end

    local set = {}

    for i, dep in ipairs(copy) do
        set[dep] = true
    end

    for i, dep in ipairs(copy) do
        local assemblyId, scope = getDepAssemblyAndScope(dep)
        local depProject, depId, depType = findAssembly(assemblyId)

        if depProject == nil and isThirdPartyProject(depId) then
            local thirdPartyProject = {
                group = fs.parentPath(depId),
                name = fs.fileName(depId)
            }

            local path = project.location .. "/third_party/" .. thirdPartyProject.name

            if not fs.exists(path .. "/") then
                path = _WORKING_DIR .. "/libraries/third_party/" .. thirdPartyProject.name
            end

            if fs.exists(path .. "/") then
                thirdPartyProject.files = {}
                    
                thirdPartyProject.additional_include_dirs = {
                    path .. "/src",
                    path .. "/include"
                }

                thirdPartyProject.additional_external_include_dirs = {
                    path .. "/src",
                    path .. "/include"
                }

                local srcDir = path .. "/src/" .. thirdPartyProject.name .. "/"
                if fs.exists(srcDir) then
                    thirdPartyProject.files[#thirdPartyProject.files + 1] = srcDir .. "**"
                end
                
                local includeDir = path .. "/include/" .. thirdPartyProject.name .. "/"
                if fs.exists(includeDir) then
                    thirdPartyProject.files[#thirdPartyProject.files + 1] = includeDir .. "**"
                end

                if utils.tableIsEmpty(thirdPartyProject.files) then                    
                    if os.isdir(path .. "/include/") then
                        thirdPartyProject.files[#thirdPartyProject.files + 1] = path .. "/include/**"
                    end
                    if os.isdir(path .. "/src/") then
                        thirdPartyProject.files[#thirdPartyProject.files + 1] = path .. "/src/**"
                    end

                    if utils.tableIsEmpty(thirdPartyProject.files) then
                        thirdPartyProject.files = { path .. "/**" }
                    end
                end

                thirdPartyProject.src = project.src

                if depType == nil then
                    depType = "library"
                end

                thirdPartyProject.location = path

                depProject = loadProject(depId, thirdPartyProject, thirdPartyProject.name, depType)
            end
        end

        if depProject ~= nil then
            local newDeps = getDepsRecursive(depProject, depType)
            for i, newDep in ipairs(newDeps) do
                local newDepAssemblyId, newDepScope = getDepAssemblyAndScope(newDep)

                if newDepScope == "public" and set[newDep] == nil then
                    set[newDep] = true
                    copy[#copy + 1] = newDep
                end
            end
        end
    end

    if not isProjectTypeMainType(projectType) then
        if utils.tableIsEmpty(copy) then
            copy = { getProjectId(project.group, project.name) }
        else
            copy = utils.concatTables({ getProjectId(project.group, project.name) }, copy)
        end
    end

    return copy
end

function projects.resolveDeps(proj)
    for i, projectType in ipairs(proj.types) do
        getDepsRecursive(proj, projectType)
    end
end

function projects.submit(proj)
    if type(proj) == "string" then
        local loadedProj = rythe.loadedProjects[proj]
        if loadedProj == nil then
            utils.printIndented("Project \"" .. proj .. "\" was not found!")
            return
        end

        projects.submit(loadedProj)
        return
    end

    local configSetup = { 
        [rythe.configuration.RELEASE] = setupRelease,
        [rythe.configuration.DEVELOPMENT] = setupDevelopment,
        [rythe.configuration.DEBUG] = setupDebug        
    }

    local variantSetup = {
        [rythe.configurationVariants.DEFAULT] = setupDefault,
        [rythe.configurationVariants.ASAN] = setupAsan,
        [rythe.configurationVariants.PROFILING] = setupProfiling      
    }

    for i, projectType in ipairs(proj.types) do
        local fullGroupPath = projectTypeGroupPrefix(projectType) .. proj.group
        local binDir = "build/" .. _ACTION .. "/bin/"
        utils.printIndented("Submitting " .. proj.name .. ":\t" .. projectType)

        utils.pushIndent()

        group(fullGroupPath)
        project(proj.alias .. projectNameSuffix(projectType))
            filename(proj.alias .. projectNameSuffix(projectType))
            location("build/" .. _ACTION .. "/" .. proj.group)

            fastuptodate(proj.fast_up_to_date_check)

            if proj.pre_build ~= nil then                
                prebuildcommands(proj.pre_build)
            end

            if proj.post_build ~= nil then                
                postbuildcommands(proj.post_build)
            end

            if proj.pre_link ~= nil then                
                prelinkcommands(proj.pre_link)
            end

            local allDeps = getDepsRecursive(proj, projectType)
            local allDefines = proj.defines

            if allDefines == nil then
                allDefines = {}
            end
            
            local libDirs = { fs.sanitize(proj.location .. "/third_party/lib/") }
            local linkTargets = {}
            local externalIncludeDirs = {}
            
            if not utils.tableIsEmpty(allDeps) then
                local depNames = {}
                for i, dep in ipairs(allDeps) do
                    local assemblyId, scope = getDepAssemblyAndScope(dep)
                    local depProject, depId, depType = findAssembly(assemblyId)

                    if depProject ~= nil then
                        externalIncludeDirs[#externalIncludeDirs + 1] = projectTypeFilesDir(depProject.location, depType, "")
                        
                        if isThirdPartyProject(depId) then
                            if os.isdir(depProject.location .. "/include/") then
                                externalIncludeDirs[#externalIncludeDirs + 1] = depProject.location .. "/include/"
                            elseif not os.isdir(depProject.location .. "/src/") then
                                externalIncludeDirs[#externalIncludeDirs + 1] = depProject.location
                            end
                        end

                        depNames[#depNames + 1] = depProject.alias .. projectNameSuffix(depType)
                        
                        allDefines[#allDefines + 1] = depProject.group == "" and string.upper(depProject.alias) .. "=1" or string.upper(depProject.group:gsub("[/\\]", "_")) .. "_" .. string.upper(depProject.alias:gsub("%-","_")) .. "=1"

                        libDirs[#libDirs + 1] = fs.sanitize(binDir .. depProject.group .. "/" .. depProject.name)
                        
                        if depType ~= "header-only" then
                            linkTargets[#linkTargets + 1] = depProject.alias .. projectNameSuffix(depType)
                        end
                    else
                        utils.printIndented("Dependency \"" .. assemblyId .. "\" was not found")
                    end
                end
                
                dependson(depNames)
            end

            architecture(buildSettings.architecture)
            
            local targetDir = fs.sanitize(binDir .. proj.group .. "/" .. proj.name)
            targetdir(targetDir)
            objdir(binDir .. "obj")

            if projectType ~= "util" then
                if not utils.tableIsEmpty(externalIncludeDirs) then
                    externalincludedirs(externalIncludeDirs)
                end

                if not utils.tableIsEmpty(libDirs) then
                    libdirs(libDirs)
                end
                
                if not utils.tableIsEmpty(proj.additional_link_targets) then
                    links(proj.additional_link_targets)
                    
                    if os.host() == "windows" then
                        local copyCommands = {}
                        for i, libDir in ipairs(libDirs) do
                            if libDir ~= targetDir then
                                local fullSrcPath = fs.sanitize(fs.parentPath(_MAIN_SCRIPT_DIR) .. "/" .. libDir) .. fs.getPathSeperator() .. "**.dll"
                                if not utils.tableIsEmpty(os.matchfiles(fullSrcPath)) then
                                    local fullDstPath = fs.sanitize(fs.parentPath(_MAIN_SCRIPT_DIR) .. "/" .. targetDir) .. fs.getPathSeperator()
                                    copyCommands[#copyCommands + 1] = "xcopy \"" .. fullSrcPath .. "\" \"" .. fullDstPath .. "\" /i /r /y /s /c"
                                end
                            end
                        end

                        postbuildcommands(copyCommands)
		  	        end
                end

                if not utils.tableIsEmpty(proj.additional_include_dirs) then
                    includedirs(fs.resolvePaths(proj.additional_include_dirs, proj.location))
                end

                if not utils.tableIsEmpty(proj.additional_external_include_dirs) then
                    externalincludedirs(fs.resolvePaths(proj.additional_external_include_dirs, proj.location))
                end

                defines(allDefines)
                
                language("C++")
                cppdialect(buildSettings.cppVersion)
                warnings(proj.warning_level)
                exceptionhandling(proj.disable_exceptions and "Off" or "Default" )
                floatingpoint(proj.floating_point_config)

                if proj.additional_warnings ~= nil then
                    enablewarnings(proj.additional_warnings)
                end

                if proj.exclude_warnings ~= nil then
                    disablewarnings(proj.exclude_warnings)
                end

                local compileFlags = { }

                if proj.warnings_as_errors then
                    fatalwarnings("All")
                end

                if proj.multi_core_compilation then
                    compileFlags[#compileFlags + 1] = "MultiProcessorCompile"
                end

                if proj.link_time_optimization then
                    linktimeoptimization("On")
                end
                
                flags(compileFlags)

                if proj.vector_extensions ~= nil then
                    vectorextensions(proj.vector_extensions)
                end

                if proj.isa_extensions ~= nil then
                    isaextensions(proj.isa_extensions)
                end

                if proj.debug_args ~= nil then
                    debugargs(proj.debug_args)
                end

                intrinsics("On")
            end

            if projectType == "application" then
                filter { "system:windows" }
				    files { proj.location .. "/**resources.rc", proj.location .. "/**.ico" }
		  	    filter {}
            end

            local projectSrcDir = projectTypeFilesDir(proj.location, projectType, proj.namespace)

            local filePatterns = fs.resolvePaths(proj.files, projectSrcDir)

            if projectType == "test" then
                filePatterns[#filePatterns + 1] = _MAIN_SCRIPT_DIR .. "/utils/test utils/**"

                vpaths({ ["test utils"] = _MAIN_SCRIPT_DIR .. "/utils/test utils/**" })
            end

            if proj.pch_enabled and isProjectTypeMainType(projectType) then
                local pchHeader, pchSource, pchParentDir

                local lastDirIndex = string.match(proj.pch_file_name, "^.*()/")
                if string.find(proj.pch_file_name, "^(%.[/\\])") == nil then
                    if lastDirIndex == nil then
                        pchParentDir = projectSrcDir
                        local fullPchPath = projectSrcDir .. proj.pch_file_name
                        pchHeader = fullPchPath .. ".hpp"
                        pchSource = fullPchPath .. ".cpp"
                    else
                        pchParentDir = string.sub(proj.pch_file_name, 1, lastDirIndex)
                        pchHeader = proj.pch_file_name .. ".hpp"
                        pchSource = proj.pch_file_name .. ".cpp"
                    end
                else
                    local fullPchPath = projectSrcDir .. string.sub(proj.pch_file_name, 3)
                    pchParentDir = projectSrcDir .. string.sub(proj.pch_file_name, 3, lastDirIndex)
                    pchHeader = fullPchPath .. ".hpp"
                    pchSource = fullPchPath .. ".cpp"
                end

                filePatterns[#filePatterns + 1] = pchHeader
                filePatterns[#filePatterns + 1] = pchSource
                
                if not os.isdir(pchParentDir) then
                    os.mkdir(pchParentDir)
                end

                if not os.isfile(pchHeader) then
                    io.writefile(pchHeader, "#pragma once\n#define RYTHE_PCH\n\n")
                    utils.printIndented("Created: " .. pchHeader)
                end

                local pchHeaderFileName = path.getname(pchHeader)

                if not os.isfile(pchSource) then
                    io.writefile(pchSource, "#include \"" .. pchHeaderFileName .. "\"\n\n")
                    utils.printIndented("Created: " .. pchSource)
                end

                includedirs({pchParentDir})
                pchheader(pchHeaderFileName)
                forceincludes({pchHeaderFileName})
                pchsource(os.getcwd() .. "/" .. pchSource)
            end

            local vPaths = { projectSrcDir }

            if proj.src ~= nil then
                filePatterns[#filePatterns + 1] = proj.src
                vPaths[#vPaths + 1] = fs.parentPath(proj.src)
            end

            vpaths({ ["*"] = vPaths})
            files(filePatterns)

            if not utils.tableIsEmpty(proj.exclude_files) then
                removefiles(fs.resolvePaths(proj.exclude_files, projectSrcDir))
            end

            kind(kindName(projectType))
            if projectType ~= "util" then
                for i, config in pairs(rythe.configuration) do
                    configSetup[config]()
                    for j, variant in pairs(rythe.configurationVariants) do
                        variantSetup[variant](config, linkTargets)
                    end
                end
            end
        filter("")

        utils.popIndent()
    end

    group("")
end

function projects.clearAll()
    rythe.loadedProjects = {};
end

function projects.addBuiltInProjects()
    local catch2 = {
        location = _MAIN_SCRIPT_DIR .. "/libraries/third_party/catch2",
        defines = { "CATCH_AMALGAMATED_CUSTOM_MAIN" },
        additional_external_include_dirs = { "./src" },
        exclude_files = { "**/meson.build" }
    }

    projects.load(catch2)

    projects.scan(_MAIN_SCRIPT_DIR .. "/")
end

function projects.scan(path)
    local srcDirs = {}

    for i, file in ipairs(os.matchfiles(path .. "**/.rythe_project")) do
        srcDirs[#srcDirs + 1] = fs.parentPath(file)
    end

    for i, dir in ipairs(srcDirs) do
        local project = projects.load({ location = dir})
    end
end

function projects.resolveAllDeps()
    local sourceProjects = utils.copyTable(rythe.loadedProjects)
    for projectId, project in pairs(sourceProjects) do
        projects.resolveDeps(project)
    end
end

function projects.submitAll()
    for projectId, project in pairs(rythe.loadedProjects) do
        projects.submit(project)
    end
end

return projects