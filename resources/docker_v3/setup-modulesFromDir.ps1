#Install modules to platform container
Param(
    $PlatformContainer,
    $ModulesDir
)
Write-Output "Stop Container ${PlatformContainer}"
docker stop $PlatformContainer

Write-Output "Upload modules to the container"
docker cp ${ModulesDir}/. ${PlatformContainer}:/vc-platform/Modules

Write-Output "Start Container"
docker start $PlatformContainer
