#!/usr/bin/env python3
import sys
import os
import re
import shutil
import argparse
import json
import subprocess
import urllib.request
import urllib.error
import uuid

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def http_error_303(self, req, fp, code, msg, headers):
        return fp
    def http_error_302(self, req, fp, code, msg, headers):
        return fp

def crop_image(src_path, dst_path, x, y, w, h):
    try:
        crop_arg = f"{int(w)}x{int(h)}+{int(x)}+{int(y)}"
        subprocess.run(["magick", src_path, "-crop", crop_arg, "+repage", "-strip", dst_path], check=True, capture_output=True)
        return True
    except Exception as e:
        sys.stderr.write(f"Crop error: {e}\n")
        return False

def upload_to_temporary_host(img_path):
    # 1. Primary: uguu.se (<0.7s, direct nginx static file serving, no Cloudflare block)
    try:
        boundary = uuid.uuid4().hex
        with open(img_path, 'rb') as f:
            img_data = f.read()

        body = (
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="files[]"; filename="selection.png"\r\n'
            f'Content-Type: image/png\r\n\r\n'
        ).encode('utf-8') + img_data + f'\r\n--{boundary}--\r\n'.encode('utf-8')

        req = urllib.request.Request(
            'https://uguu.se/upload',
            data=body,
            headers={
                'User-Agent': 'NilastiaCTS/1.0',
                'Content-Type': f'multipart/form-data; boundary={boundary}'
            }
        )
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data.get('success') and data.get('files'):
                return data['files'][0]['url']
    except Exception as e:
        sys.stderr.write(f"uguu.se upload warning: {e}\n")

    # 2. Secondary Fallback: freeimage.host (<0.8s, direct iili.io CDN serving, no Cloudflare block)
    try:
        boundary = uuid.uuid4().hex
        with open(img_path, 'rb') as f:
            img_data = f.read()

        body = (
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="key"\r\n\r\n6d207e02198a847aa98d0a2a901485a5\r\n'
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="action"\r\n\r\nupload\r\n'
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="format"\r\n\r\njson\r\n'
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="source"; filename="selection.png"\r\n'
            f'Content-Type: image/png\r\n\r\n'
        ).encode('utf-8') + img_data + f'\r\n--{boundary}--\r\n'.encode('utf-8')

        req = urllib.request.Request(
            'https://freeimage.host/api/1/upload',
            data=body,
            headers={
                'User-Agent': 'NilastiaCTS/1.0',
                'Content-Type': f'multipart/form-data; boundary={boundary}'
            }
        )
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if 'image' in data and 'url' in data['image']:
                return data['image']['url']
    except Exception as e:
        sys.stderr.write(f"freeimage.host upload warning: {e}\n")

    return None

def get_lens_url(img_path):
    pub_url = upload_to_temporary_host(img_path)
    if pub_url:
        import urllib.parse
        return f"https://lens.google.com/upload?url={urllib.parse.quote(pub_url, safe=':/?=')}"
    return None

def copy_to_clipboard(path):
    try:
        with open(path, "rb") as f:
            subprocess.run(["wl-copy", "--type", "image/png"], input=f.read(), check=True)
    except Exception as e:
        sys.stderr.write(f"wl-copy image error: {e}\n")

def resolve_browser(preferred="auto"):
    # If the user explicitly configured a specific browser:
    if preferred and preferred.strip().lower() != "auto":
        bin_name = preferred.strip()
        bin_path = shutil.which(bin_name)
        if bin_path:
            name = os.path.basename(bin_path).lower()
            if any(c in name for c in ["brave", "chrome", "chromium", "vivaldi", "edge", "opera"]):
                return bin_path, "chromium"
            elif any(f in name for f in ["firefox", "zen", "librewolf", "waterfox", "floorp"]):
                return bin_path, "firefox"
            return bin_path, "generic"
        sys.stderr.write(f"Configured browser '{preferred}' not found in PATH, falling back to auto-detection\n")

    # 1. Chromium-based browsers supporting native --app= frameless mode
    chromium_bins = [
        "brave",
        "google-chrome-stable",
        "google-chrome",
        "chromium",
        "chromium-browser",
        "vivaldi",
        "microsoft-edge-stable",
        "microsoft-edge",
        "opera",
    ]
    for b in chromium_bins:
        bin_path = shutil.which(b)
        if bin_path:
            return bin_path, "chromium"

    # 2. Gecko/Firefox-based browsers supporting --new-window
    firefox_bins = [
        "zen-browser",
        "zen",
        "firefox",
        "firefox-developer-edition",
        "librewolf",
        "waterfox",
        "floorp",
    ]
    for b in firefox_bins:
        bin_path = shutil.which(b)
        if bin_path:
            return bin_path, "firefox"

    # 3. Desktop generic handler via xdg-open
    if shutil.which("xdg-open"):
        return "xdg-open", "generic"

    return None, None

def main():
    parser = argparse.ArgumentParser(description="Nilastia Google Lens Upload Service")
    parser.add_argument("--image", default="/tmp/cts-screen.png", help="Path to input image")
    parser.add_argument("--crop", default="", help="Crop box: x,y,w,h")
    parser.add_argument("--browser", default="auto", help="Browser binary to launch (default: auto)")
    parser.add_argument("--copy-only", action="store_true", help="Only copy cropped selection to clipboard")
    parser.add_argument("--no-launch", action="store_true", help="Do not launch browser, only return URL")

    args = parser.parse_args()

    target_img = args.image
    if args.crop:
        try:
            parts = [int(float(p)) for p in args.crop.split(",")]
            if len(parts) == 4 and parts[2] > 10 and parts[3] > 10:
                crop_path = "/tmp/cts-crop.png"
                if crop_image(args.image, crop_path, parts[0], parts[1], parts[2], parts[3]):
                    target_img = crop_path
        except Exception as e:
            sys.stderr.write(f"Failed to parse crop: {e}\n")

    # Copy image to clipboard via wl-copy
    copy_to_clipboard(target_img)

    if args.copy_only:
        subprocess.run([
            "notify-send",
            "-a", "Circle to Search",
            "-i", "content_copy",
            "Circle to Search",
            "Cropped selection copied to clipboard"
        ])
        print(json.dumps({"status": "copied", "image": target_img}))
        return 0

    try:
        target_url = get_lens_url(target_img)
        if not target_url:
            target_url = "https://lens.google.com/"
            subprocess.run([
                "notify-send",
                "-a", "Circle to Search",
                "-i", "network-offline",
                "Circle to Search",
                "Network offline. Selection copied to clipboard - paste into Google Lens."
            ])

        if not args.no_launch:
            browser_bin, browser_type = resolve_browser(args.browser)
            if not browser_bin:
                subprocess.run([
                    "notify-send",
                    "-a", "Circle to Search",
                    "-i", "travel_explore",
                    "Circle to Search",
                    "Selection copied to clipboard. No web browser found on system."
                ])
                print(json.dumps({
                    "status": "no_browser",
                    "message": "Selection copied to clipboard. No web browser found on system.",
                    "url": target_url,
                    "clipboard": True
                }))
                return 0

            if browser_type == "chromium":
                subprocess.Popen([browser_bin, f"--app={target_url}", "--window-size=640,980"], start_new_session=True)
            elif browser_type == "firefox":
                subprocess.Popen([browser_bin, "--new-window", target_url], start_new_session=True)
            else:
                subprocess.Popen([browser_bin, target_url], start_new_session=True)

            print(json.dumps({
                "status": "ok",
                "url": target_url,
                "browser": browser_bin,
                "type": browser_type
            }))
            return 0
        else:
            print(json.dumps({"status": "ok", "url": target_url}))
            return 0
    except Exception as e:
        sys.stderr.write(f"Lens error: {e}\n")
        print(json.dumps({"status": "error", "message": str(e)}))
        return 1

if __name__ == "__main__":
    sys.exit(main())
