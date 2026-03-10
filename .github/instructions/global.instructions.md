---
applyTo: "**"
description: "Common Windows OS codebase build system and development guidance for all environments"
title: "Windows OS Development Instructions (Common)"
version: "2.0.0"
owner: "aep-es-copilot@microsoft.com"
---

# Windows OS Codebase Instructions

These instructions apply to all environments (VS Code, CLI, and other IDEs).

# Content Exclusion Policy
This codebase contains files that are configured to be ignored by Copilot content exclusion feature. If any tool signals a file is excluded/blocked/ignored/restricted → STOP.
- Accept the result as final
- Inform the user the content is excluded due to organizational policy
- Do NOT retry with alternative methods such as:
    - Terminal commands (`cat`, `type`, `Get-Content`, .NET file methods)
    - Shell redirection, piping, or indirect access



## Environment Context

### Razzle Environment
- Working on Windows OS repositories requires running in a "Razzle" environment
- Detect Razzle by checking if `$env:SDXROOT` is set
- `$env:SDXROOT` identifies the root of the repository where the code is cloned
- **IMPORTANT**: `$env:SDXROOT` expands to `<enlistment_root>\src` (e.g., `C:\os\src`). Do **not** append `\src` when constructing paths — use `$env:SDXROOT\<component>` directly (e.g., `$env:SDXROOT\sdktools\windiff`, not `$env:SDXROOT\src\sdktools\windiff`)

### VFS for Git Constraints

**Quick rule:** `os.2020` repo = VFS enabled. Other repos (e.g., `OSClient`) = standard git, no VFS constraints.

**Verification:** `git config --get core.gvfs` returns "true" if VFS-enabled.

**IMPORTANT**: VFS repositories lazily fetch files on access (hydration), so directory scans trigger network calls.

**Best Practices (VFS repos only):**
- **Avoid broad directory traversals** - Use targeted searches instead of exploring large directory trees
- **Work locally** - Stay in the current working directory or nearby subdirectories when possible
- **Use precise file paths** - When you know the file location, access it directly rather than searching
- **Limit search scope** - Constrain searches to specific directories rather than repo-wide
- **Batch operations** - Make multiple targeted file reads in parallel rather than sequential exploration
- **Minimize file system operations** - VFS for Git adds overhead to each file access
- **Cache information** - Remember results from file reads rather than re-reading

## Build System Overview

### Core Files
- **`dirs`** - Specifies all child directories that is part of the build graph
- **`project.mk`** - Project-wide configuration and compiler settings
- **`sources`** or **`makefile.inc`** - Component-specific build configuration using NMake
- **`*.*proj`** (except `product.pbxproj` or `dirs.proj`) - Component-specific build configuration using MSBuild
- **`product.pbxproj`** - Pass3 build configuration
- **`sources.dep`** - Intra-pass build and publics dependencies

### Sources Files (Build System)
A `sources` file is a build specification file that defines macros that trigger build actions on the source files of the containing directory to produce a target file. Build.exe calls NMake with `makefile.def` (`%SDXROOT%/tools/makefile.def`) for directories with a `sources` file and `makefile.def` imports the `sources` file.

### *.*proj Files (Build System)
A `*.*proj` file is a build specification file that defines targets and properties that trigger build actions for a directory that is built using MSBuild instead of NMake. A `product.pbxproj` file is a special msbuild proj file that defines pass3 operations related to packaging, imaging, signing, kits and other post-compile actions. A `dirs.proj` file is a special MSBuild file used to define project dependencies and these should no longer be used in the Windows codebase.

### Dirs Files (Build System)
A `dirs` file is a build specification file that lists all the direct subdirectories to include in the build graph. When Build.exe, the build engine for the os repo, is invoked in a directory with a `dirs` file, it will also build all children directories as it recurses down the tree of directories found in the `dirs` files.

A directory participates in the build process either as:
- **Branch directory**: Contains a `dirs` file that lists subdirectories for the build to include
- **Leaf project**: Contains a `sources` file or a msbuild proj file (`*.*proj` excluding `dirs.proj`) that specifies how to build its contained source code files

A branch directory (with a `dirs` file) has subdirectories that are each a sub-branch (with a `dirs` file), a project (with a `sources` or `*.*proj` file), or not built because it is not listed in the `dirs` file. A project directory can contain subdirectories, but those directories are not buildable.

### Build Artifacts
Build artifacts are placed in the current working directory. However, log files can be redirected to a different location using the build parameter /jpath. `build /jpath [pathname]` uses the specified pathname for log files instead of the current directory.

- `build*.err` - Build errors (check this first!)
- `build*.log` - Full build logs
- `buildfre.*` - Free/release build output
- `buildchk.*` - Checked/debug build output

## Directory Structure

### Top-Level Organization
```
\os\src\
├── admin\          # Administrative tools and components
├── amcore\         # Anti-malware core components
├── avcore\         # Audio/Video core components
├── base\           # Base operating system components
├── clientcore\     # Client-specific components
├── com\            # COM and RPC components
├── drivers\        # Device drivers
├── ds\             # Directory services
├── enduser\        # End-user applications
├── gamecore\       # Gaming platform components
├── inetcore\       # Internet/networking core
├── mincore\        # Minimal core components
├── minkernel\      # Minimal kernel
├── multimedia\     # Multimedia components
├── net\            # Networking components
├── onecore\        # OneCore unified platform
├── pcshell\        # PC shell components
├── printscan\      # Print and scan subsystem
├── server\         # Server-specific components
├── services\       # System services
├── shell\          # Shell and UI components
├── termsrv\        # Terminal services
├── tools\          # Build tools and utilities
├── windows\        # Windows-specific components
└── xbox\           # Xbox platform components
```

### Naming Conventions
- **Architecture-specific builds**: `{component}{amd64,arm64}` in `dirs` files
- **Test components**: `test\`, `unittests\`, `unittest\` subdirectories
- **Published interfaces**: `inc\`, `published\` directories
- **Implementation**: Component-named directories (e.g., `rtl\`, `mm\`, `hal\`)
- **Exclusion patterns**: `{!x86,!chpe}` to exclude certain architectures

## Build Configuration

### Configuration Hierarchy
1. **Global**: `\os\src\project.mk` (if exists)
2. **Component**: Each major component has its own `project.mk`
3. **Module**: Individual `sources` files override inherited settings

### Target Types
- **LIBRARY**: Static library (.lib)
- **DYNLINK**: Dynamic link library (.dll)
- **PROGRAM**: Executable (.exe)
- **DRIVER**: Kernel driver (.sys)

### Unit Testing Structure
```
component\
├── src\           # Production code
├── unittests\     # Unit test suites
│   ├── dirs       # Test subdirectories
│   ├── testarea1\ # Individual test areas
│   └── testarea2\
└── unittest\      # Alternative test structure
```

#### Build System Diagnostics
1. **Verify dirs file**: Check subdirectory listing and architecture filters
2. **Review project.mk**: Look for inherited settings and feature flags
3. **Examine sources.dep**: Verify intra-pass dependencies

#### Environment Verification
- **Build Environment**: Verify `RAZZLETOOLPATH`, `BASEDIR`, and `OBJECT_ROOT` are set
- **Architecture**: Confirm `_BUILDARCH` matches intended target
- **Build Flavor**: Check `_BUILDALT` and `FREEBUILD` settings
- **Tool Availability**: Ensure compilers and build tools are accessible

## Best Practices for AI Systems

### Code Analysis Patterns
1. **Start with Directory Structure**: Use `dirs` files to understand component organization
2. **Follow Build Dependencies**: Intra-pass component relationships are in `sources.dep` but inter-pass dependencies are not recorded in source control.
3. **Check Feature Flags**: Look for conditional compilation in `project.mk` files
4. **Identify Test Patterns**: Look for `unittests\` and `unittest\` directories

### Making Changes
1. **Understand Multi-Pass**: Changes to headers may require PASS0 dependency updates
2. **Respect Architecture Boundaries**: Use appropriate `#ifdef` for platform-specific code
3. **Follow Naming Conventions**: Match existing patterns for files and directories
4. **Update Build Files**: Remember to update `sources` files when adding/removing files

### Testing Approach
1. **Unit Tests**: Look for existing unit tests in `unittests\` directories
2. **Integration Tests**: Check for test-specific `dirs` filtering
3. **Build Verification**: Ensure changes don't break multi-architecture builds
4. **Feature Testing**: Use feature flags to enable/disable test features


#### Simple Library Component
```
mylibrary\
├── makefil0               # Build entry point
├── project.mk             # Component configuration
├── sources.inc            # Build specification
├── sources.dep            # Same pass dependencies
├── precomp.h              # Precompiled header
├── mylib.c                # Implementation
├── mylib.h                # Public interface
└── amd64\
    └── asm_helpers.asm    # Architecture-specific code
```

#### Component with Unit Tests
```
mycomponent\
├── dirs                   # Includes src and unittests
├── src\
│   ├── sources.inc        # Production code build
│   ├── component.c        # Implementation
│   └── component.h        # Interface
└── unittests\
    ├── dirs               # Test subdirectories
    ├── basic\
    │   ├── sources        # Unit test build
    │   └── test_basic.c   # Test implementation
    └── advanced\
        ├── sources        # Advanced test build
        └── test_advanced.c
```

