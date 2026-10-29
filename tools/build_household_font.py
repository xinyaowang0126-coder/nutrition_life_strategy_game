"""Build the game's static medium-weight Noto Sans subset (FontTools 4.60.1).

Only needed when adding new interface copy; runtime uses the committed TTF.
python -m pip install fonttools==4.60.1
python tools/build_household_font.py
"""

from pathlib import Path
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fonttools-path", type=Path)
    args = parser.parse_args()
    if args.fonttools_path:
        sys.path.insert(0, str(args.fonttools_path.resolve()))
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont

    root = Path(__file__).resolve().parents[1] / "life-strategy"
    chars = set(chr(code) for code in range(32, 127))
    for folder, extension in [("scripts", "*.gd"), ("data", "*.xml"), ("data", "*.json"), ("scenes", "*.tscn")]:
        for source in (root / folder).rglob(extension):
            chars.update(source.read_text(encoding="utf-8-sig"))
    chars.update("，。！？：；‘’“”（）【】《》、—…·℃¥×＋−／→≤≥")
    source = root / "assets/fonts/NotoSansSC-VF.ttf"
    font = TTFont(source)
    copyright_text = "\n".join(sorted({record.toUnicode() for record in font["name"].names if record.nameID == 0}))
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14, 16, 17]
    options.name_legacy = True
    options.name_languages = ["*"]
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes={ord(char) for char in chars})
    subsetter.subset(font)
    instantiateVariableFont(font, {"wght": 500}, inplace=True)
    names = {1: "Household Sans SC", 2: "Medium", 3: "HouseholdSansSC-Medium-v1", 4: "Household Sans SC Medium", 6: "HouseholdSansSC-Medium", 16: "Household Sans SC", 17: "Medium"}
    for record in font["name"].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    destination = root / "assets/fonts/HouseholdSansSC-Medium.ttf"
    font.save(destination)
    license_text = (root / "assets/fonts/NotoSerifSC-OFL.txt").read_text(encoding="utf-8")
    license_text = license_text[license_text.index("This Font Software"):]
    (root / "assets/fonts/HouseholdSans-OFL.txt").write_text(copyright_text + "\n\n" + license_text, encoding="utf-8")
    print(f"Built {destination.name}: {destination.stat().st_size:,} bytes, {len(font.getBestCmap()):,} codepoints, static weight 500")


if __name__ == "__main__":
    main()
