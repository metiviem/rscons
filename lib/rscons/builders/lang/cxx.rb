Rscons::Builders::Object.register(command: "${CXXCMD}", direct_command: "${CXXCMD:direct}", suffix: "${CXXSUFFIX}", preferred_ld: "${CXX}")
Rscons::Builders::SharedObject.register(command: "${SHCXXCMD}", direct_command: "${SHCXXCMD:direct}", suffix: "${CXXSUFFIX}", preferred_ld: "${SHCXX}")
