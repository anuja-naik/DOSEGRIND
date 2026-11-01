enum GrindTexture { coarse, medium, smooth, fine }

enum JarType { chutney, chopper, multipurpose, liquidising }

extension JarTypeInfo on JarType {
  String get label => switch (this) {
        JarType.chutney => 'Chutney & spice · 500 mL',
        JarType.chopper => 'Chopper · 500 mL',
        JarType.multipurpose => 'Multipurpose · 1 L',
        JarType.liquidising => 'Liquidising · 1.5 L',
      };
  double get capacityMl => switch (this) {
        JarType.chutney || JarType.chopper => 500,
        JarType.multipurpose => 1000,
        JarType.liquidising => 1500,
      };
}

class Ingredient {
  const Ingredient(this.name, this.quantity, this.unit);
  final String name;
  final double quantity;
  final String unit;
  Ingredient scale(double factor) => Ingredient(name, quantity * factor, unit);
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.summary,
    required this.ingredients,
    required this.jar,
    required this.knobPosition,
    required this.liquidMl,
    required this.grindSeconds,
    required this.intervals,
    required this.restSeconds,
    required this.texture,
    required this.precautions,
    required this.icon,
    this.imageAsset,
  });
  final String id;
  final String name;
  final String category;
  final String summary;
  final List<Ingredient> ingredients;
  final JarType jar;
  final String knobPosition;
  final int liquidMl;
  final int grindSeconds;
  final int intervals;
  final int restSeconds;
  final GrindTexture texture;
  final List<String> precautions;
  final String icon;
  final String? imageAsset;

  double get baseIngredientMass => ingredients.fold(0, (s, i) => s + i.quantity);
  Recipe scaled(double factor) => Recipe(
        id: id,
        name: name,
        category: category,
        summary: summary,
        ingredients: ingredients.map((i) => i.scale(factor)).toList(),
        jar: jar,
        knobPosition: knobPosition,
        liquidMl: (liquidMl * factor).round(),
        grindSeconds: grindSeconds,
        intervals: intervals,
        restSeconds: restSeconds,
        texture: texture,
        precautions: precautions,
        icon: icon,
        imageAsset: imageAsset,
      );
}

class RecipeRecommendation {
  const RecipeRecommendation({required this.batchCount, required this.totalSeconds, required this.intervals, required this.liquidMl, required this.notes});
  final int batchCount;
  final int totalSeconds;
  final int intervals;
  final int liquidMl;
  final List<String> notes;
}
