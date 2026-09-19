"""
build_models.py

Headless Blender (bpy) script that procedurally builds a cohesive set of
stylized low-poly 3D models for the idle-adventure game and exports each one
as a separate .glb into game/assets/models/.

Run:
    /projects/sandbox/tools/blender-5.2.1-linux-x64/blender \
        --background --python /projects/sandbox/game/tools_blender/build_models.py

Design goals:
    * Intentional stylized low-poly look: modest polycount + flat shading.
    * Each model centered at world origin, sane game-unit scale (hero ~1.7 tall).
    * Every object gets a Principled BSDF material with a base_color so the
      Godot glTF importer picks up colors.
    * Each model exported to its own clean .glb via use_selection=True.
"""

import math
import os

import bpy
import bmesh
from mathutils import Vector

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# game/tools_blender/build_models.py  ->  game/assets/models
GAME_DIR = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(GAME_DIR, "assets", "models")
os.makedirs(OUT_DIR, exist_ok=True)

exported_files = []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def clear_scene():
    """Remove every object plus orphaned mesh/material data for a clean slate."""
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)


def make_material(name, color):
    """Create a Principled BSDF material with a solid base color."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    # diffuse_color is used by some importers / the viewport fallback.
    mat.diffuse_color = (color[0], color[1], color[2], 1.0)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
        # Slightly rough, non-metallic stylized surfaces.
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 0.8
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def set_material(obj, color, name=None):
    """Assign a single material with the given color to an object's mesh."""
    mat = make_material(name or (obj.name + "_mat"), color)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return mat


def apply_flat_shading(obj):
    """Give the object the faceted low-poly look."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_flat()


def join_objects(objects, name):
    """Join a list of objects into one, return the joined object."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    active = objects[0]
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    active.name = name
    active.data.name = name + "_mesh"
    return active


def center_and_scale(obj, target_height=None, floor_at_zero=True):
    """Center the object on the origin in XY, optionally normalise height."""
    bpy.context.view_layer.update()
    # Recompute bounds in world space.
    coords = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    min_v = Vector((min(c.x for c in coords), min(c.y for c in coords), min(c.z for c in coords)))
    max_v = Vector((max(c.x for c in coords), max(c.y for c in coords), max(c.z for c in coords)))
    size = max_v - min_v
    center = (min_v + max_v) * 0.5

    if target_height and size.z > 1e-6:
        factor = target_height / size.z
        obj.scale = (obj.scale.x * factor, obj.scale.y * factor, obj.scale.z * factor)
        bpy.context.view_layer.update()
        coords = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        min_v = Vector((min(c.x for c in coords), min(c.y for c in coords), min(c.z for c in coords)))
        max_v = Vector((max(c.x for c in coords), max(c.y for c in coords), max(c.z for c in coords)))
        center = (min_v + max_v) * 0.5

    # Move so it's centered on X/Y and sits on the ground (z=0) if requested.
    obj.location.x -= center.x
    obj.location.y -= center.y
    if floor_at_zero:
        obj.location.z -= min_v.z
    bpy.context.view_layer.update()


def finalize(obj, color, name, target_height=None, floor_at_zero=True):
    """Common finish steps: material, flat shading, transforms, apply scale."""
    if obj.data.materials:
        pass  # keep multi-material objects (e.g. hero) as-is
    else:
        set_material(obj, color, name + "_mat")
    apply_flat_shading(obj)
    center_and_scale(obj, target_height=target_height, floor_at_zero=floor_at_zero)
    # Apply transforms so exported glb has clean identity transform.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def export_glb(obj, filename):
    """Export just the given object as a GLB."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )
    exported_files.append(path)


# ---------------------------------------------------------------------------
# Primitive helpers (return the newly created active object)
# ---------------------------------------------------------------------------
def add_cube(size=1.0, location=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cube_add(size=size, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def add_cylinder(radius=0.5, depth=1.0, verts=8, location=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, vertices=verts, location=location
    )
    return bpy.context.active_object


def add_cone(radius1=0.5, radius2=0.0, depth=1.0, verts=8, location=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(
        radius1=radius1, radius2=radius2, depth=depth, vertices=verts, location=location
    )
    return bpy.context.active_object


def add_ico(radius=0.5, subdiv=1, location=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=radius, subdivisions=subdiv, location=location
    )
    return bpy.context.active_object


def add_uvsphere(radius=0.5, segments=10, rings=6, location=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius, segments=segments, ring_count=rings, location=location
    )
    return bpy.context.active_object


# ---------------------------------------------------------------------------
# Palette (stylized, cohesive)
# ---------------------------------------------------------------------------
C_SKIN = (0.86, 0.66, 0.50)
C_BODY = (0.30, 0.45, 0.72)     # tunic blue
C_CLOAK = (0.72, 0.20, 0.22)    # red cloak
C_BOOTS = (0.28, 0.20, 0.14)    # brown boots/belt
C_HAIR = (0.20, 0.14, 0.10)

C_TRUNK = (0.42, 0.28, 0.16)
C_LEAF = (0.24, 0.55, 0.28)

C_ROCK = (0.48, 0.50, 0.54)

C_WOOD = (0.45, 0.30, 0.17)
C_GOLD = (0.92, 0.74, 0.20)

C_SLIME = (0.30, 0.78, 0.45)
C_SLIME_EYE = (0.05, 0.05, 0.08)

C_CRYSTAL = (0.45, 0.75, 0.95)

C_GROUND = (0.36, 0.52, 0.30)

C_COIN = (0.95, 0.80, 0.25)
C_RUNE = (0.55, 0.35, 0.85)
C_RUNE_GLOW = (0.80, 0.65, 1.0)


# ---------------------------------------------------------------------------
# Model builders
# ---------------------------------------------------------------------------
def build_hero():
    clear_scene()
    parts = []

    # Body / tunic (tapered box)
    body = add_cube(size=1.0, location=(0, 0, 1.0), scale=(0.34, 0.24, 0.5))
    set_material(body, C_BODY, "hero_body")
    parts.append(body)

    # Belt
    belt = add_cube(size=1.0, location=(0, 0, 0.78), scale=(0.36, 0.26, 0.06))
    set_material(belt, C_BOOTS, "hero_belt")
    parts.append(belt)

    # Legs
    for sx in (-0.16, 0.16):
        leg = add_cube(size=1.0, location=(sx, 0, 0.32), scale=(0.11, 0.13, 0.34))
        set_material(leg, C_BOOTS, "hero_legs")
        parts.append(leg)

    # Arms
    for sx in (-0.42, 0.42):
        arm = add_cube(size=1.0, location=(sx, 0, 1.02), scale=(0.1, 0.12, 0.34))
        set_material(arm, C_BODY, "hero_arms")
        parts.append(arm)

    # Head (distinct, sits above body)
    head = add_cube(size=1.0, location=(0, 0, 1.62), scale=(0.24, 0.24, 0.24))
    set_material(head, C_SKIN, "hero_head")
    parts.append(head)

    # Hair cap
    hair = add_cube(size=1.0, location=(0, -0.02, 1.78), scale=(0.27, 0.27, 0.12))
    set_material(hair, C_HAIR, "hero_hair")
    parts.append(hair)

    # Cloak (flat slab behind the body, distinct color)
    cloak = add_cube(size=1.0, location=(0, 0.22, 1.05), scale=(0.4, 0.06, 0.6))
    set_material(cloak, C_CLOAK, "hero_cloak")
    parts.append(cloak)

    hero = join_objects(parts, "hero")
    finalize(hero, C_BODY, "hero", target_height=1.7, floor_at_zero=True)
    export_glb(hero, "hero.glb")


def build_tree():
    clear_scene()
    parts = []
    trunk = add_cylinder(radius=0.22, depth=1.3, verts=7, location=(0, 0, 0.65))
    set_material(trunk, C_TRUNK, "tree_trunk")
    parts.append(trunk)

    # Stacked cones for stylized foliage
    foliage_cfg = [
        (0.95, 1.0, 1.35),
        (0.72, 0.9, 2.0),
        (0.5, 0.8, 2.55),
    ]
    for radius, depth, z in foliage_cfg:
        cone = add_cone(radius1=radius, radius2=0.0, depth=depth, verts=8, location=(0, 0, z))
        set_material(cone, C_LEAF, "tree_leaf")
        parts.append(cone)

    tree = join_objects(parts, "tree")
    finalize(tree, C_LEAF, "tree", target_height=3.0, floor_at_zero=True)
    export_glb(tree, "tree.glb")


def build_rock():
    clear_scene()
    rock = add_ico(radius=0.7, subdiv=1, location=(0, 0, 0))
    # Distort verts for an irregular boulder shape.
    me = rock.data
    bm = bmesh.new()
    bm.from_mesh(me)
    for i, v in enumerate(bm.verts):
        f = 0.78 + 0.32 * ((i * 37) % 7) / 7.0
        v.co = v.co * f
        v.co.z *= 0.8
    bm.to_mesh(me)
    bm.free()
    set_material(rock, C_ROCK, "rock")
    rock.name = "rock"
    finalize(rock, C_ROCK, "rock", target_height=0.9, floor_at_zero=True)
    export_glb(rock, "rock.glb")


def build_chest():
    clear_scene()
    parts = []
    # Chest base
    base = add_cube(size=1.0, location=(0, 0, 0.3), scale=(0.6, 0.42, 0.3))
    set_material(base, C_WOOD, "chest_base")
    parts.append(base)

    # Lid (rounded via a low-vert cylinder half-ish, use a scaled box + cylinder cap)
    lid = add_cube(size=1.0, location=(0, 0, 0.66), scale=(0.62, 0.44, 0.14))
    set_material(lid, C_WOOD, "chest_lid")
    parts.append(lid)

    # Gold band trim
    band = add_cube(size=1.0, location=(0, 0, 0.5), scale=(0.63, 0.45, 0.04))
    set_material(band, C_GOLD, "chest_band")
    parts.append(band)

    # Lock
    lock = add_cube(size=1.0, location=(0, -0.44, 0.5), scale=(0.1, 0.04, 0.1))
    set_material(lock, C_GOLD, "chest_lock")
    parts.append(lock)

    chest = join_objects(parts, "chest")
    finalize(chest, C_WOOD, "chest", target_height=0.9, floor_at_zero=True)
    export_glb(chest, "chest.glb")


def build_enemy():
    clear_scene()
    parts = []
    # Slime body: squashed ico-sphere
    body = add_ico(radius=0.6, subdiv=1, location=(0, 0, 0.5))
    body.scale = (1.0, 1.0, 0.85)
    set_material(body, C_SLIME, "enemy_body")
    parts.append(body)

    # Eyes
    for sx in (-0.2, 0.2):
        eye = add_ico(radius=0.1, subdiv=1, location=(sx, -0.52, 0.62))
        set_material(eye, C_SLIME_EYE, "enemy_eye")
        parts.append(eye)

    enemy = join_objects(parts, "enemy")
    finalize(enemy, C_SLIME, "enemy", target_height=0.9, floor_at_zero=True)
    export_glb(enemy, "enemy.glb")


def build_crystal():
    clear_scene()
    parts = []
    # Central large crystal: cone up + cone down to make a bipyramid-ish shard.
    top = add_cone(radius1=0.35, radius2=0.0, depth=1.1, verts=6, location=(0, 0, 0.95))
    set_material(top, C_CRYSTAL, "crystal_top")
    parts.append(top)
    bottom = add_cone(radius1=0.35, radius2=0.0, depth=0.6, verts=6, location=(0, 0, 0.1))
    bottom.rotation_euler = (math.pi, 0, 0)
    set_material(bottom, C_CRYSTAL, "crystal_bottom")
    parts.append(bottom)

    # Two smaller side shards
    for sx, rot in ((-0.4, -0.35), (0.42, 0.4)):
        shard = add_cone(radius1=0.18, radius2=0.0, depth=0.7, verts=6, location=(sx, 0, 0.55))
        shard.rotation_euler = (0, rot, 0)
        set_material(shard, C_CRYSTAL, "crystal_shard")
        parts.append(shard)

    crystal = join_objects(parts, "crystal")
    finalize(crystal, C_CRYSTAL, "crystal", target_height=1.5, floor_at_zero=True)
    export_glb(crystal, "crystal.glb")


def build_coin():
    """A small spinning gold coin pickup used for reward feedback."""
    clear_scene()
    coin = add_cylinder(radius=0.35, depth=0.08, verts=12, location=(0, 0, 0))
    # Lay it upright like a standing coin.
    coin.rotation_euler = (math.pi / 2.0, 0, 0)
    set_material(coin, C_COIN, "coin")
    coin.name = "coin"
    finalize(coin, C_COIN, "coin", target_height=0.5, floor_at_zero=True)
    export_glb(coin, "coin.glb")


def build_rune():
    """A glowing rune marker (obelisk) that marks zone waypoints."""
    clear_scene()
    parts = []
    # Base slab
    base = add_cube(size=1.0, location=(0, 0, 0.12), scale=(0.34, 0.34, 0.12))
    set_material(base, C_RUNE, "rune_base")
    parts.append(base)
    # Obelisk shaft
    shaft = add_cube(size=1.0, location=(0, 0, 0.75), scale=(0.18, 0.18, 0.62))
    set_material(shaft, C_RUNE, "rune_shaft")
    parts.append(shaft)
    # Glowing tip
    tip = add_cone(radius1=0.22, radius2=0.0, depth=0.5, verts=6, location=(0, 0, 1.55))
    set_material(tip, C_RUNE_GLOW, "rune_tip")
    parts.append(tip)

    rune = join_objects(parts, "rune")
    finalize(rune, C_RUNE, "rune", target_height=2.0, floor_at_zero=True)
    export_glb(rune, "rune.glb")


def build_ground():
    clear_scene()
    # A simple square ground tile, subtly domed for a stylized feel.
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0, 0, 0))
    ground = bpy.context.active_object
    # Add a small thickness so it reads as a tile, not a paper plane.
    solid = ground.modifiers.new(name="Solidify", type="SOLIDIFY")
    solid.thickness = 0.15
    solid.offset = -1.0
    set_material(ground, C_GROUND, "ground")
    ground.name = "ground"
    finalize(ground, C_GROUND, "ground", target_height=None, floor_at_zero=False)
    export_glb(ground, "ground.glb")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    builders = [
        build_hero,
        build_tree,
        build_rock,
        build_chest,
        build_enemy,
        build_crystal,
        build_coin,
        build_rune,
        build_ground,
    ]
    for b in builders:
        b()

    print("\n==== EXPORTED MODELS ====")
    for p in exported_files:
        size = os.path.getsize(p) if os.path.exists(p) else -1
        print("  {}  ({} bytes)".format(p, size))
    print("==== {} models written to {} ====".format(len(exported_files), OUT_DIR))


if __name__ == "__main__":
    main()
