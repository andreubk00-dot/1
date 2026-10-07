# OSTATOK 1.30.0-dev3 — General Visual & Clipping Pass

Финальный общий visual/capture-pass 1.30 выполнен без изменения art/gameplay geometry.

## Проверено на Godot 4.7.2

- residential building: runtime Xvfb capture;
- commercial building: runtime Xvfb capture;
- industrial building: runtime Xvfb capture;
- rail building: runtime Xvfb capture;
- dacha building: runtime Xvfb capture;
- ранее в dev2: все четыре High Risk visual families.

Проверялись фасады, roof fade, interiors, doors, roadside geometry, props и крупные композиции. Подтверждённого clipping/overlap дефекта, требующего rebuild, не найдено.

## Boundary

- gameplay geometry не менялась;
- PNG assets не менялись;
- save schema остаётся 122;
- historical 1.22 gates не переписывались;
- 1.30 закрывается как QA/final visual validation, а не как forced art rewrite.
