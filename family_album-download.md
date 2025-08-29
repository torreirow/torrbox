```
# 📖 Guide: Using `mitene_download` on NixOS

This guide explains how to set up a dedicated Python environment, install and use `mitene_download` to download your FamilyAlbum media, and convert the downloaded `.webp` files into `.png` images.

---

## 1. 🐍 Create a dedicated Python environment

First, make sure you have a recent Python (≥ 3.9). On NixOS, you can enable it via:

```bash
nix-shell -p python311
```

Then create a dedicated virtual environment:

```bash
python3.11 -m venv ~/python_envs/mitene
source ~/python_envs/mitene/bin/activate
```

Your shell prompt should now show `(mitene)`.

---

## 2. 📦 Installing `mitene_download`

### Option A: Install from PyPI (recommended)

```bash
pip install mitene-download
```

After installation, verify it works:

```bash
mitene_download --help
```

---

### Option B: Install from source

If you prefer to build it yourself:

```bash
git clone https://github.com/mzp/mitene-download.git
cd mitene-download
pip install .
```

This will install the latest development version into your virtual environment.

---

## 3. 📥 Downloading your FamilyAlbum images

To download media from your FamilyAlbum share URL:

```bash
mitene_download --destination-directory ./album <album_url>
```

- Replace `<album_url>` with your actual FamilyAlbum share link.  
- All photos, videos, and comments will be saved into the `./album` directory.

---

## 4. 🎨 Converting `.webp` to `.png` with `ffmpeg`

`mitene_download` saves images in **WebP** format. To convert them into **PNG**:

1. Install ffmpeg:

```bash
nix-shell -p ffmpeg
```

2. Run the conversion:

```bash
for f in album/*.webp; do
    ffmpeg -i "$f" "${f%.webp}.png"
done
```

This will keep the original `.webp` files and create `.png` versions alongside them.

---

## 5. 🔍 Notes on formats

- **Keep the original `.webp`** files: they are smaller and preserve quality.  
- **Use PNG** if you want lossless image data.  
- **Use JPG** (instead of PNG) if you want smaller files that are easier to share — replace `".png"` with `".jpg"` in the conversion loop above.

---

## 6. 🛑 Deactivate the environment

When you’re done:

```bash
deactivate
```

This will exit the virtual environment.

---

✅ That’s it! You now have a clean workflow for downloading and converting your FamilyAlbum media on NixOS.
```

