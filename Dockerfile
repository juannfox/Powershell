#Reference:
#https://hub.docker.com/_/alpine
#https://docs.microsoft.com/en-us/powershell/scripting/install/install-alpine?view=powershell-7.2

FROM alpine:3.14
ARG apk_packages="ca-certificates less ncurses-terminfo-base krb5-libs libgcc libintl libssl1.1 libstdc++ tzdata userspace-rcu zlib icu-libs curl"
ARG pwsh_version="7.2.6"
ARG script

#APK bootstrap
RUN apk add sudo
RUN sudo apk add --no-cache $apk_packages
RUN sudo apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache lttng-ust

#Powershell install
RUN curl -L https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-alpine-x64.tar.gz -o /tmp/powershell.tar.gz
RUN sudo mkdir -p /opt/microsoft/powershell/7
RUN sudo tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7
RUN sudo chmod +x /opt/microsoft/powershell/7/pwsh
RUN sudo ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

#Container init
ENTRYPOINT ["pwsh"]
CMD ["-Command", "Write-Output test"]