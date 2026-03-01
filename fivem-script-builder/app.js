const form = document.getElementById("generatorForm");
const fileTabs = document.getElementById("fileTabs");
const filePreview = document.getElementById("filePreview");
const resourceHint = document.getElementById("resourceHint");
const downloadJsonBtn = document.getElementById("downloadJsonBtn");
const downloadZipBtn = document.getElementById("downloadZipBtn");
const saveFolderBtn = document.getElementById("saveFolderBtn");

let generatedFiles = {};
let activeFile = "";
let lastResourceName = "my_fivem_script";

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

const sanitizeResourceName = (name) =>
  name
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_")
    .replace(/[^a-z0-9_\-]/g, "") || "my_fivem_script";

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
    "}",
    withHtml ? "" : "",
    withHtml
      ? `files {\n    'html/index.html',\n    'html/style.css',\n    'html/app.js'\n}\n\nui_page 'html/index.html'`
      : ""
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

const ensureGenerated = () => {
  if (!Object.keys(generatedFiles).length) {
    resourceHint.textContent = "لازم تولّد الملفات أولاً.";
    return false;
  }

  return true;
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

const downloadJson = () => {
  if (!ensureGenerated()) {
    return;
  }

  const blob = new Blob([JSON.stringify(generatedFiles, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `${lastResourceName}.blueprint.json`;
  anchor.click();
  URL.revokeObjectURL(url);
};

const downloadZip = async () => {
  if (!ensureGenerated()) {
    return;
  }

  if (!window.JSZip) {
    resourceHint.textContent = "تعذر تحميل JSZip. تأكد من وجود إنترنت أو حمّل الملف يدوياً.";
    return;
  }

  const zip = new window.JSZip();
  const rootFolder = zip.folder(lastResourceName);

  Object.entries(generatedFiles).forEach(([path, content]) => {
    rootFolder.file(path, content);
  });

  const zipBlob = await zip.generateAsync({ type: "blob" });
  const zipUrl = URL.createObjectURL(zipBlob);
  const anchor = document.createElement("a");
  anchor.href = zipUrl;
  anchor.download = `${lastResourceName}.zip`;
  anchor.click();
  URL.revokeObjectURL(zipUrl);

  resourceHint.textContent = `تم تجهيز ${lastResourceName}.zip ✅`;
};

const writeFileByPath = async (baseDirectoryHandle, path, content) => {
  const parts = path.split("/");
  const fileName = parts.pop();
  let currentHandle = baseDirectoryHandle;

  for (const directory of parts) {
    currentHandle = await currentHandle.getDirectoryHandle(directory, { create: true });
  }

  const fileHandle = await currentHandle.getFileHandle(fileName, { create: true });
  const writable = await fileHandle.createWritable();
  await writable.write(content);
  await writable.close();
};

const saveDirectlyToFolder = async () => {
  if (!ensureGenerated()) {
    return;
  }

  if (typeof window.showDirectoryPicker !== "function") {
    resourceHint.textContent =
      "المتصفح الحالي لا يدعم الحفظ المباشر. استخدم Chrome/Edge أو نزّل ZIP.";
    return;
  }

  try {
    const selectedFolder = await window.showDirectoryPicker({ mode: "readwrite" });
    const resourceFolder = await selectedFolder.getDirectoryHandle(lastResourceName, {
      create: true
    });

    const writeJobs = Object.entries(generatedFiles).map(([path, content]) =>
      writeFileByPath(resourceFolder, path, content)
    );

    await Promise.all(writeJobs);
    resourceHint.textContent = `تم حفظ الملفات مباشرة داخل ${lastResourceName} ✅`;
  } catch (error) {
    if (error && error.name === "AbortError") {
      resourceHint.textContent = "تم إلغاء عملية الحفظ.";
      return;
    }

    resourceHint.textContent = "حدث خطأ أثناء الحفظ المباشر. جرّب تنزيل ZIP.";
  }
};

form.addEventListener("submit", (event) => {
  event.preventDefault();

  const formData = new FormData(form);
  const normalizedResourceName = sanitizeResourceName(formData.get("resourceName") || "");

  form.elements.resourceName.value = normalizedResourceName;

  const data = {
    resourceName: normalizedResourceName,
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
  lastResourceName = normalizedResourceName;
  activeFile = Object.keys(generatedFiles)[0];
  renderTabs();
  filePreview.textContent = generatedFiles[activeFile];
  resourceHint.textContent =
    `تم إنشاء ${Object.keys(generatedFiles).length} ملف داخل ${data.resourceName}. الآن تقدر تنزل ZIP أو تحفظ مباشرة.`;
});

downloadJsonBtn.addEventListener("click", downloadJson);
downloadZipBtn.addEventListener("click", () => {
  downloadZip().catch(() => {
    resourceHint.textContent = "فشل تجهيز ZIP. جرّب مرة ثانية.";
  });
});
saveFolderBtn.addEventListener("click", () => {
  saveDirectlyToFolder().catch(() => {
    resourceHint.textContent = "فشل الحفظ المباشر. جرّب تنزيل ZIP.";
  });
});
