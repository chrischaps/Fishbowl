-- Shared constants for the tank.
-- The tank is a shallow 3D box seen through its front glass: world x/y are
-- pixels at the front glass, d is depth (0 = back glass, 1 = front glass).

local C = {}

C.W, C.H = 1280, 720

-- Projection: points farther back shrink toward this vanishing point
C.CX, C.CY = 640, 290
C.K_BACK = 0.84             -- projected scale at the back glass

C.SURFACE_Y = 34            -- world y of the water surface
C.FLOOR_Y = 652             -- world y of the substrate at the front glass
C.FLOOR_RISE = 34           -- substrate slopes up toward the back (aquascape style)
C.DEPTH_PX = 420            -- world px per unit of depth, for 3D motion

C.FAR_D = 0.3               -- objects behind this are drawn soft (depth of field)

C.CYCLE_SECONDS = 600       -- one full day/night cycle

C.BUBBLER_X, C.BUBBLER_D = 150, 0.22

-- The aquascape (rocks, wood, plants) is composed from a fixed seed so the
-- tank looks the same every visit; the fish are free to do as they like.
C.SCAPE_SEED = 2

return C
