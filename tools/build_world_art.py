"""OSTATOK 0.88.0 — rebuild all exterior world art (0.87 world + 0.88 facades).
Usage: python3 tools/build_world_art.py <project_dir>"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import wa_ground, wa_building, wa_props, wa_facade, wa_detail, wa_poi, wa_interior, wa_settlement, wa_settlement_ground, wa_buildings, wa_hr_buildings, wa_hr_props, prop_regions

P = sys.argv[1]
wa_ground.build(os.path.join(P, 'ground_chunk_v12.png'))
wa_building.build_all(P)
# individual seamless roof tiles + edge strips (Godot cannot repeat an AtlasTexture region)
rt = Image.open(os.path.join(P, 'roof_tiles_v3.png'))
ed = Image.open(os.path.join(P, 'roof_edges_v1.png'))
for st in range(6):
    rt.crop((st * 64, 0, st * 64 + 64, 64)).save(os.path.join(P, 'roof_tile_s%d_v3.png' % st))
    ed.crop((0, st * 8, 64, st * 8 + 8)).save(os.path.join(P, 'roof_edge_h_s%d_v1.png' % st))
    ed.crop((64 + st * 8, 0, 64 + st * 8 + 8, 64)).save(os.path.join(P, 'roof_edge_v_s%d_v1.png' % st))
wa_props.build_all(P)
wa_facade.build_all(P)
wa_facade.build_090(P)
wa_detail.build_all(P)
wa_poi.build_all(P)
wa_settlement.build_all(P)
wa_settlement_ground.build_all(P)
wa_buildings.build_all(P, os.path.join(P, 'world', 'settlement_building_models.gd'))
wa_hr_buildings.build_all(P, os.path.join(P, 'world', 'high_risk_building_models.gd'))
wa_hr_props.build_all(P)
wa_interior.build_all(P, prop_regions.load(os.path.join(P, 'main_script_mod.gd')))
print('world art ok')
