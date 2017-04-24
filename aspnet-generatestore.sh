#!/usr/bin/env bash

set -euo pipefail

install_dir="<auto>"
aspnet_version="<auto>"
framework="netcoreapp2.0"
framework_version="<auto>"
architecture="x64"
runtime_id="" # must be provided
work_dir="./.temp"

while [ $# -ne 0 ]
do
    name=$1
    case $name in
        --aspnet-version)
            shift
            aspnet_version="$1"
            ;;
        -i|--install-dir)
            shift
            install_dir="$1"
            ;;
        --arch|--architecture)
            shift
            architecture="$1"
            ;;
        -f|--framework)
            shift
            framework="$1"
            ;;
        --fx-version)
            shift
            framework_version="$1"
            ;;
        -r|--runtime-id)
            shift
            runtime_id="$1"
            ;;
        -?|--?|-h|--help|-[Hh]elp)
            script_name="$(basename $0)"
            echo "ASP.NET package store generation"
            echo "Usage: $script_name [-r <RUNTIME ID>"
            echo "       $script_name -h|-?|--help"
            echo ""
            echo "$script_name is a simple command line interface for obtaining dotnet cli."
            echo ""
            echo "Options:"
            echo "  --aspnet_version <VERSION>            Use specified ASP.NET version. Defaults to latest available."
            echo "  --f,--framework <FRAMEWORK>           Use specifed framework target. Defaults to ``netcoreapp2.0``"
            echo "  --fx-version <VERSION>                Use specifed shared framework version. Defaults to latest available."
            echo "  -i,--install-dir <DIR>                Creates store in specified location. Defaults to ``.store``"
            echo "  --arch,--architecture <ARCHITECTURE>  Architecture of .NET Tools."
            echo "  -r,--runtime-id                       Generates the store for the specified runtime identifier."
            echo "  -?,--?,-h,--help,-Help                Shows this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown argument \`$name\`"
            exit 1
            ;;
    esac

    shift
done

if [ -z "$runtime_id" ]
then
    echo "runtime id is required"
    exit 1
fi

# Clean the 'install directory'. We don't support multiple concurrent versions.'
if [ "$install_dir" = "<auto>" ]
then
    install_dir="./.store"
fi

if [ -d "$install_dir" ]
then
    rm "$install_dir" -r
fi

if [ ! -d "$install_dir" ]
then
    mkdir "$install_dir"
fi

#Make $install_dir fully-qualified
install_dir="$(cd "$(dirname "$install_dir")"; pwd)/$(basename "$install_dir")"

# Blow away the 'working directory' used by dotnet store. dotnet store is bad at cleaning this up.
if [ -d "$work_dir" ]
then
    rm "$work_dir"
fi

if [ "$framework_version" = "<auto>" ]
then
    echo "Autodetecting shared framework version"
    dotnet="$(which dotnet)"
    dotnet_root="$(dirname $dotnet)"

    echo "dotnet root is $dotnet_root"

    framework_version="$(ls $dotnet_root/shared/Microsoft.NETCore.App -A | tail -1)"
    echo "Selected version $framework_version"
fi

if [ "$aspnet_version" = "<auto>" ]
then
    echo "Autodetecting ASP.NET version"

    dotnet restore ./GetLatestAspNetVersion.proj --packages ./.packages
    
    aspnet_version="$(ls ./.packages/microsoft.aspnetcore.all -A | tail -1)"
    echo "Selected version $aspnet_version"
fi

#These environment variables are used by dotnet store
export JITBENCH_ASPNET_VERSION="$aspnet_version"
export JITBENCH_FRAMEWORK_VERSION="$framework_version"

echo "Running dotnet store"
dotnet store --manifest "./CreateStore.proj" -f "$framework" -r "$runtime_id" --framework-version "$framework_version" -w "$work_dir" -o "$install_dir"

manifest="$install_dir/$architecture/$framework/artifact.xml"

echo "Setting JITBENCH_ASPNET_VERSION to $aspnet_version"
export JITBENCH_ASPNET_VERSION="$aspnet_version"

echo "Setting JITBENCH_FRAMEWORK_VERSION to $framework_version"
export JITBENCH_FRAMEWORK_VERSION="$framework_version"

echo "Setting JITBENCH_ASPNET_MANIFEST to $manifest"
export JITBENCH_ASPNET_MANIFEST="$manifest"

echo "Setting DOTNET_SHARED_STORE to $install_dir"
export DOTNET_SHARED_STORE="$install_dir"