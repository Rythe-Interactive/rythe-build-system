[![rythe logo banner](https://assets.zyrosite.com/dWxb3NO0jWugObXN/logo_for_dark_bg-A3QwL7kkxvfw1ywO.png)](http://rythe-interactive.com)
[![License-MIT](https://img.shields.io/github/license/Rythe-Interactive/rythe-build-system)](https://github.com/Rythe-Interactive/rythe-build-system/blob/main/LICENSE)
[![Discord](https://img.shields.io/discord/682321168610623707.svg?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)](https://discord.gg/unVNRbd)

These are the Premake build-system scripts for the Rythe ecosystem.

Rythe uses a build system built on top of Premake5.
Using the rythe premake module you can define projects and workspaces.

Projects can either be manually defined, or automatically detected through .rythe_project files.
.rythe_project files also allows you to customize the project, and report third-party dependencies that don't use the rythe build system.

# Workspaces

Workspaces define the different project folders with different available configurations. In visual studio every workspace is a seperate solution file.

## Definition

| Field name      | Default value | Description                                             |
|-----------------|---------------|---------------------------------------------------------|
| name            | nil           | Name of the workspace.                                  |
| location        | nil           | Location to generate the workspace at.                  |
| configurations  | [empty]       | List of configurations to enable for this workspace.    |

# Projects

The rythe build system defines any action as projects, this can be compiling code, but it can also be executing arbitrary commands.
Projects are also the main way of interacting with the rythe build system.

## Definition

| Field name                          | Default value                 | Description                                                                                                                          |
|-------------------------------------|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| init                                | nil                           | Initialization function, this allows you to dynamically change project fields upon project load based on the workspace context       |
| alias                               | <Project name>                | Alias for the project name                                                                                                           |
| namespace                           | ""                            | Project namespace, also used for folder structures                                                                                   |
| types                               | <Based on folder structure>   | Target types this projet uses, valid values: "application", "module", "editor", "library", "header-only", "util", "test"             |
| additional_types                    | [empty]                       | Extra target types to add to the project, can be used if you don't want to override the default project types                        |
| dependencies                        | [empty]                       | Project dependency definitions, format: [(optional)<public|private>(default <private>)] [path][(optional):<type>(default <library>)] |
| fast_up_to_date_check               | true                          | Enable or disable Visual Studio check if project outputs are already up to date (handy to turn off on util projects)                 |
| warning_level                       | "High"                        | Compiler warning level to enable, valid values: "Off", "Default", "Extra", "High", "Everything"                                      |
| warnings_as_errors                  | true                          | Treat warnings as errors                                                                                                             |
| additional_warnings                 | nil                           | List of additional warnings to enable, for Visual Studio this needs to be the warning number instead of the name                     |
| exclude_warnings                    | nil                           | List of warnings to explicitly disable, for Visual Studio this needs to be the warning number instead of the name                    |
| disable_exceptions                  | true                          | Disable exceptions                                                                                                                   |
| floating_point_config               | "Default"                     | Floating point configuration for the compiler to use, valid values: "Default", "Fast", "Strict", "None"                              |
| vector_extensions                   | nil                           | Which vector extension to enable, see: https://premake.github.io/docs/vectorextensions/                                              |
| isa_extensions                      | nil                           | see: https://premake.github.io/docs/isaextensions/                                                                                   |
| defines                             | [empty]                       | Additional defines on top of the default ones Rythe will add (PROJECT_NAME, PROJECT_FULL_NAME, PROJECT_NAMESPACE)                    |
| files                               | ["./**"]                      | File filter patterns to find source files with                                                                                       |
| exclude_files                       | nil                           | Exclude patterns to exclude source files with                                                                                        |
| additional_include_dirs             | [empty]                       | Additional include dirs for #include ""                                                                                              |
| additional_external_include_dirs    | [empty]                       | Additional external include dirs for #include <> on top of the ones Rythe will auto detect from dependencies                         |
| additional_link_targets             | [empty]                       | Additional prebuilt libraries to link.                                                                                               |
| pre_build                           | nil                           | Prebuild command                                                                                                                     |
| post_build                          | nil                           | Postbuild command                                                                                                                    |
| pre_link                            | nil                           | Prelink command                                                                                                                      |
| multi_core_compilation              | true                          | Allow project to be compiled in parallel                                                                                             |
| link_time_optimization              | true                          | Enable LTO                                                                                                                           |
| pch_enabled                         | false                         | Enable precompiled headers                                                                                                           |
| pch_file_name                       | "pch"                         | File name for pch header and pch source files (e.g. pch.hpp and pch.cpp will have the name: "pch")                                   |

## Project types

Projects can have many different project types. If none were specified then the build system will attempt to detect it from the folder structure of where the project lives.
Each project type does different things or has different side effects/outputs when built. A project is mostly organized around a collection of files and a location.
So if multiple different actions need to happen revolving the same folder, it's recommended to use different project types instead of multiple different projects.
The exception is for util projects, util projects can not have any other types than util.

### application

Application projects, as the name suggests, generates an executable application upon build.
This is used for for instance you final output executable, or for executable tools that can be run standalone.
This project type can also be usefull for examples or tests that don't require the test framework automatically added to test projects.

### module

Module projects are projects that compile into a rythe module, to either be statically linked, or dynamically loaded by the rythe runtime.
All modules by default depend on the rythe-core module in order to get the prerequisites of linking/loading and behaving like a rythe module.

### editor

Editor projects are projects that compile into a rythe editor module.
Editor projects are expected to be bundled with a module project, and will automatically get the module project as a dependency.
The main goal of this project type is to provide editor tooling and compatibility with the module project.
Similar to normal modules, these by default depend on rythe-core.
The main difference is that these projects also depend on rythe-editor, and have access to editor only frameworks.
These modules will only be dynamically loaded by the rythe editor runtime, and will be ignored by the rythe release runtimes.

### library

Library projects are simple libraries with no other extras. These can either be statically or dynamically compiled and linked by other projects.

### header-only

As the name suggests, this is for header-only libraries that don't require compilation.
These can be depended on by other projects. The rythe build system will then take of the include paths.

### util

Util projects can't be bundled with any other project types. Util projects aren't expected to have any particular effect or output.
Util projects can be used to execute any kind of command or list of commands.
Other projects can depend on the util project in order to make sure the util project is always run before the build of the project.

### test

Test projects are projects that automatically depend on whatever other project type was added, and also automatically gets access to the test framework.
The primary goal of this project type is for unit testing.