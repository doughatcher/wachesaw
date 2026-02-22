FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG GODOT_VERSION=4.4

# Install Godot headless binary
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget unzip ca-certificates \
    && GODOT_FULL_VERSION="${GODOT_VERSION}-stable" \
    && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_FULL_VERSION}/Godot_v${GODOT_FULL_VERSION}_linux.x86_64.zip" -O /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_FULL_VERSION}_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip \
    && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_FULL_VERSION}/Godot_v${GODOT_FULL_VERSION}_export_templates.tpz" -O /tmp/templates.tpz \
    && mkdir -p /root/.local/share/godot/export_templates/${GODOT_FULL_VERSION} \
    && unzip /tmp/templates.tpz -d /tmp \
    && mv /tmp/templates/* /root/.local/share/godot/export_templates/${GODOT_FULL_VERSION}/ \
    && ln -sf /root/.local/share/godot/export_templates/${GODOT_FULL_VERSION} /root/.local/share/godot/export_templates/$(echo ${GODOT_FULL_VERSION} | sed 's/-/./') \
    && rm -rf /tmp/templates /tmp/templates.tpz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install GTK4 Python bindings and X11 support for the level editor
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-gi \
        gir1.2-gtk-4.0 \
        x11-apps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS, Wrangler CLI, and Expo CLI
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g wrangler@latest @expo/cli@latest \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
