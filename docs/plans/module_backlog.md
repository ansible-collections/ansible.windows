# Module Backlog - ACA-6275: Package Management Modernization

**Epic**: ACA-6275  
**Collection**: ansible.windows  
**Mode**: Enhancement (adding new functionality to existing collection)  
**Generated**: 2026-06-01

---

## Modules to Implement

### 1. win_winget - Winget Package Manager

**Status**: [x] DONE  
**Type**: New module  
**Priority**: High

**Purpose**: Manage Windows packages using Microsoft's official winget package manager

**Key Parameters**:
- `name` - Package identifier (e.g., "Microsoft.VisualStudioCode")
- `state` - present, absent, latest
- `source` - Package source name (optional, defaults to winget default sources)
- `version` - Specific version to install (optional)
- `scope` - user or machine (installation scope)

**Operations**:
- Install packages from winget repositories
- Upgrade existing packages
- Uninstall packages
- List installed packages (check mode)
- Manage custom package sources

**Test Requirements**:
- Verify winget is available (Windows 11/Server 2025)
- Test install/upgrade/uninstall flows
- Test custom sources
- Test scope parameter (user vs machine)
- Idempotency validation

**Platform Requirements**:
- Windows 11 or Windows Server 2025 (winget built-in)
- OR Windows 10/Server 2019-2022 with winget manually installed

---

### 2. win_package_management - PackageManagement Provider Support

**Status**: [x] DONE  
**Type**: New module (alternative to enhancing win_package)  
**Priority**: High

**Purpose**: Extend existing win_package module to support PackageManagement (OneGet) providers

**Current State**:
- `win_package` currently supports: MSI, EXE, MSP, MSU, APPX installers
- Does not support PowerShell PackageManagement providers

**Enhancement**:
- Add `provider` parameter to support: NuGet, PowerShellGet, Chocolatey (via provider), custom providers
- Integrate with `PackageManagement` PowerShell module
- Support provider-based package installation/removal

**New Parameters**:
- `provider` - PackageManagement provider name (e.g., "NuGet", "PowerShellGet")
- `source` - Package source/repository for the provider
- `provider_options` - Dict of provider-specific options

**Operations**:
- Install packages via PackageManagement providers
- Remove packages via providers
- Query package state via providers
- Support custom provider repositories

**Test Requirements**:
- Test NuGet provider
- Test PowerShellGet provider  
- Test custom repositories
- Ensure backward compatibility with existing win_package functionality
- Idempotency validation

**Platform Requirements**:
- PackageManagement module (built-in on modern Windows)
- PowerShellGet module (for PowerShellGet provider tests)

---

## Implementation Notes

**Pattern Matching**:
- Study existing `win_chocolatey` module for package management patterns
- Study existing `win_package` module for current implementation
- Follow ansible.windows coding standards (see existing modules)

**Code Reuse Opportunities**:
- Package state validation logic
- Idempotency checking patterns
- Error handling for missing dependencies
- Test infrastructure from existing package modules

**Dependencies**:
- No new collection dependencies
- Runtime dependencies: winget (for win_winget), PackageManagement module (for win_package enhancement)

**Delivery Timeline**:
- Phase 1: win_winget implementation (3-4 hours)
- Phase 2: win_package enhancement (2-3 hours)
- Phase 3: Testing and validation (1-2 hours)
- Phase 4: Code review and refinement (1 hour)

---

## Module Status Legend

- `[ ]` - TODO (not started)
- `[~]` - IN PROGRESS (actively being worked on)
- `[x]` - DONE (completed and passing all tests)
- `[!]` - CODE COMPLETE, TESTS BLOCKED (code written but integration tests cannot run)
