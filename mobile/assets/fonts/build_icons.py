import sys, re
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset
src_font, codepoints, out_font, out_dart = sys.argv[1:5]
names = """home add_a_photo calendar_month insights person scale photo_camera auto_awesome verified link_off menu_book
notifications notifications_active help content_copy search chevron_right chevron_left add remove tune science edit_note
photo_library edit close swap_horiz search_off restaurant restaurant_menu notes local_fire_department link light_mode
dark_mode folder_open exposure_zero download check camera_enhance bolt wifi warning track_changes shield schedule replay
remove_circle refresh phone_iphone no_food logout language fact_check edit_calendar done_all devices delete
delete_forever check_circle build arrow_forward add_task add_circle mic""".split()
cp = dict(l.split() for l in open(codepoints) if l.strip())
missing = [n for n in names if n not in cp]
assert not missing, missing
f = TTFont(src_font)
print('axes', [a.axisTag for a in f['fvar'].axes])
opts = subset.Options(); opts.layout_features = []; opts.name_IDs = ['*']; opts.notdef_outline = True; opts.glyph_names = False
s = subset.Subsetter(opts); s.populate(unicodes=[int(cp[n], 16) for n in names]); s.subset(f)
f = instancer.instantiateVariableFont(f, {"wght": 500, "opsz": 24, "GRAD": 0})
for n in f['name'].names:
    if n.nameID in (1, 4, 16): n.string = 'Miqdar Symbols'
f.save(out_font)
mirror = {'chevron_right', 'chevron_left', 'arrow_forward', 'logout'}
def camel(n):
    p = n.split('_'); return p[0] + ''.join(x.capitalize() for x in p[1:])
lines = ["import 'package:flutter/widgets.dart';", "",
 "/// Material Symbols Rounded, weight 500, cut down to the icons the app uses.",
 "/// Pass `fill: 1` to an Icon for the filled form (selected tabs, the calorie flame).",
 "/// To add one, add its name to the font build and regenerate this file; see assets/fonts/README.md.",
 "abstract final class MiqdarIcons {", "  static const _font = 'MiqdarSymbols';", ""]
for n in names:
    extra = ', matchTextDirection: true' if n in mirror else ''
    lines.append(f"  static const {camel(n)} = IconData(0x{cp[n]}, fontFamily: _font{extra});")
lines.append("}"); open(out_dart, 'w').write('\n'.join(lines) + '\n')
print(len(names), 'icons')
