
#!/usr/bin/env bash
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $root

runtime="ubuntu.14.04-x64"
shared_framework_runtime="linux-x64"
if [ "$TRAVIS_OS_NAME" = "osx" ]
then
    ulimit -n 2048
    runtime="osx.10.12-x64"
    shared_framework_runtime="osx.10.12-x64"
fi

echo "Installing latest dotnet"
./dotnet-install.sh -sharedruntime -runtimeid "$shared_framework_runtime" -installdir .dotnet -version 2.0.0 -architecture x64
source ./dotnet-install.sh -installdir .dotnet -version 2.0.0 -architecture x64

dotnet --info

echo "Applying workaround for SDK bug 1682"
cp ./CreateStore/bugfix_sdk_1682/Microsoft.NET.ComposeStore.targets ./.dotnet/sdk/2.0.0/Sdks/Microsoft.NET.Sdk/build/Microsoft.NET.ComposeStore.targets

echo "Creating local package store"
source ./aspnet-generatestore.sh -i .store --arch x64 -r "$runtime"

echo "Restoring MusicStore"
cd src/MusicStore
dotnet restore

echo "Publishing MusicStore"
dotnet publish -c Release -f netcoreapp2.0 --manifest $JITBENCH_ASPNET_MANIFEST

echo "Running MusicStore"
cd bin/Release/netcoreapp2.0/publish
output=$(dotnet ./MusicStore.dll | tee /dev/tty; exit ${PIPESTATUS[0]})

if [[ "$output" == *"ASP.NET loaded from bin"* ]]
then
    echo "ASP.NET was not loaded from the store. This is a bug. CI will now fail."
    exit 1
fi

echo "Success"
