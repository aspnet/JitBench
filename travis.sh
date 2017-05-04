
#!/usr/bin/env bash
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $root

runtime="ubuntu.14.04-x64"
if [ "$TRAVIS_OS_NAME" = "osx" ]
then
    runtime="osx.10.12-x64"
fi

echo "Installing latest dotnet"
source ./dotnet-install.sh -installdir .dotnet -channel master -architecture x64

dotnet --info

echo "Creating local package store"
source ./aspnet-generatestore.sh -i .store --arch x64 -r "$runtime"

echo "Restoring MusicStore"
cd src/MusicStore
dotnet restore

echo "Publishing MusicStore"
dotnet publish -c Release -f netcoreapp2.0 --manifest $JITBENCH_ASPNET_MANIFEST

echo "Running MusicStore"
cd bin/Release/netcoreapp2.0/publish
dotnet ./MusicStore.dll