const form = document.getElementById("generatorForm");
const fileTabs = document.getElementById("fileTabs");
const filePreview = document.getElementById("filePreview");
const resourceHint = document.getElementById("resourceHint");
const downloadJsonBtn = document.getElementById("downloadJsonBtn");

let generatedFiles = {};
let activeFile = "";

const getFrameworkSnippet = (framework) => {
  if (framework === "qb") {
    return {
      manifest: "dependency 'qb-core'",
      sharedTop: "local QBCore = exports['qb-core']:GetCoreObject()"
    };
  }

  if (framework === "esx") {
    return {
      manifest: "dependency 'es_extended'",
      sharedTop: "local ESX = exports['es_extended']:getSharedObject()"
    };
  }

  return {
    manifest: "",
    sharedTop: "-- بدون Framework"
  };
};

const buildFiles = (data) => {
  const {
    resourceName,
    author,
    version,
    framework,
    game,
    fxVersion,
    withConfig,
    withLocales,
    withHtml,
    withReadme,
    cfgLine
  } = data;

  const frameworkSnippet = getFrameworkSnippet(framework);

  const manifestLines = [
    `fx_version '${fxVersion}'`,
    `game '${game}'`,
    "",
    `name '${resourceName}'`,
    `author '${author}'`,
    `version '${version}'`,
    "lua54 'yes'",
    "",
    frameworkSnippet.manifest,
    "",
    "client_scripts {",
    "    'client/*.lua'",
    "}",
    "",
    "server_scripts {",
    "    'server/*.lua'",
    "}",
    "",
    "shared_scripts {",
    withConfig ? "    'config.lua'," : "",
    "    'shared/*.lua'",
    "}"
  ].filter(Boolean);

  const files = {
    "fxmanifest.lua": manifestLines.join("\n"),
    "client/main.lua": `RegisterCommand('hello_${resourceName}', function()\n    print('Client command works ✅')\nend, false)`,
    "server/main.lua": `RegisterCommand('hello_server_${resourceName}', function(source)\n    print(('Command triggered by %s'):format(source))\nend, true)`,
    "shared/main.lua": `${frameworkSnippet.sharedTop}\n\nShared = Shared or {}\nShared.Resource = '${resourceName}'`
  };

  if (withConfig) {
    files["config.lua"] = `Config = {}\n\nConfig.Debug = true\nConfig.Locale = 'ar'\nConfig.Framework = '${framework}'`;
  }

  if (withLocales) {
    files["locales/ar.lua"] = `Locales = Locales or {}\n\nLocales['ar'] = {\n    greeting = 'هلا والله بك داخل ${resourceName}'\n}`;
  }

  if (withHtml) {
    files["html/index.html"] = "<!doctype html>\n<html><body><h1>FiveM NUI جاهزة</h1></body></html>";
    files["html/style.css"] = "body { font-family: sans-serif; background: #121212; color: #fff; }";
    files["html/app.js"] = "console.log('NUI Ready');";
  }

  if (withReadme) {
    files["README.md"] = `# ${resourceName}\n\nسكريبت مولّد تلقائياً بواسطة FiveM Script Starter.\n\n## Server.cfg\n\n\`\`\`cfg\n${cfgLine || `ensure ${resourceName}`}\n\`\`\``;
  }

  if (cfgLine) {
    files["server.cfg.snippet.txt"] = cfgLine;
  }

  return files;
};

const renderTabs = () => {
  fileTabs.innerHTML = "";
  Object.keys(generatedFiles).forEach((path) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `tab ${path === activeFile ? "active" : ""}`;
    button.textContent = path;
    button.addEventListener("click", () => {
      activeFile = path;
      renderTabs();
      filePreview.textContent = generatedFiles[path];
    });
    fileTabs.appendChild(button);
  });
};

form.addEventListener("submit", (event) => {
  event.preventDefault();

  const formData = new FormData(form);
  const data = {
    resourceName: formData.get("resourceName").trim(),
    author: formData.get("author").trim(),
    version: formData.get("version").trim(),
    framework: formData.get("framework"),
    game: formData.get("game").trim(),
    fxVersion: formData.get("fxVersion"),
    withConfig: formData.get("withConfig") === "on",
    withLocales: formData.get("withLocales") === "on",
    withHtml: formData.get("withHtml") === "on",
    withReadme: formData.get("withReadme") === "on",
    cfgLine: formData.get("cfgLine").trim()
  };

  generatedFiles = buildFiles(data);
  activeFile = Object.keys(generatedFiles)[0];
  renderTabs();
  filePreview.textContent = generatedFiles[activeFile];
  resourceHint.textContent = `تم إنشاء ${Object.keys(generatedFiles).length} ملف داخل ${data.resourceName}`;
});

downloadJsonBtn.addEventListener("click", () => {
  if (!Object.keys(generatedFiles).length) {
    resourceHint.textContent = "لازم تولّد الملفات أولاً قبل التحميل.";
    return;
  }

  const blob = new Blob([JSON.stringify(generatedFiles, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "fivem-starter-blueprint.json";
  anchor.click();
  URL.revokeObjectURL(url);
});
