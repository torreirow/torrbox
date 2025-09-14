# AI - prompts for various usage

## Recipes in Markdownformat
- The family recipe site: https://recepten.toorren.net
```
Je taak is om één of meerdere recepten om te zetten naar Hugo Markdown-pagina's met frontmatter. De recepten worden altijd gegeven in dit format: Maak recept: <naam recept> ingredienten: <ingredienten> bereidingswijze: <bereidingswijze> Regels voor de omzetting: 1. Behoud cups, tablespoon (tbsp) en teaspoon (tsp) zoals ze zijn. 2. Zet alle andere eenheden om naar metrisch en geef de metrische waarde tussen haakjes achter de originele hoeveelheid, bijvoorbeeld: - 3 oz → 85 g - 1 lb → 0.45 kg - 110 °F → 43 °C - vloeistoffen: cups/oz → milliliter, bijv. 1 cup → 240 ml 3. Maak frontmatter aan met de volgende velden: - title: de naam van het recept - ref: kleine letters, spaties vervangen door koppeltekens - image: true - category: bepaal de categorie (bijv. brood, hoofdgerecht, dessert, bijgerecht) - tags: relevante tags (lijst) - time: totale bereidingstijd (indien opgegeven, anders inschatting) - quantity: aantal stuks of porties (indien opgegeven, anders inschatting) - ingredients: lijst van ingrediënten met name, amount en unit - side_image: ./images/<ref>.jpg 4. Voeg de bereiding toe onder ### **Bereiding**, in bullet-stappen. 5. Als er een sectie serveren of tips is, voeg die toe onder ### **Serveren**. 6. Geef de output **alleen in Markdown**, één bestand per recept. 7. Als time of quantity niet zijn opgegeven, schat deze dan realistisch in op basis van het recept. Voorbeeld Hugo Markdown met frontmatter en metrische toevoegingen:
markdown
---
title: Easy Garlic Naan Bread
ref: "easy-garlic-naan-bread"
image: true
category: brood
tags:
  - naan
  - indiaas
  - bijgerecht
time: 1 hr 30 mins
quantity: 8 stuks
ingredients:
  - name: All-purpose flour (bloem)
    amount: 3
    unit: cups (≈ 360 g)
  - name: Active dry yeast or instant yeast
    amount: 7
    unit: g (1 package)
  - name: Sugar
    amount: 1
    unit: tsp
  - name: Warm water (ca. 43 °C)
    amount: 1
    unit: cup (≈ 240 ml)
side_image: ./images/easy_garlic_naan_bread.jpg
---
### **Bereiding**
- **Gist activeren**
  - Meng in een kom de gist, suiker en warm water (43 °C).  
  - Laat 10 minuten staan tot het mengsel schuimig wordt.  
- **Deeg maken**
  - Meng in een grote kom de bloem, zout, yoghurt en olie.  
  - Voeg het gistmengsel toe en kneed 10 minuten tot een soepel deeg ontstaat.  
- **Laten rijzen**
  - Dek de kom af en laat 1 uur rijzen, of tot het deeg in volume verdubbeld is.  
- **Verdelen en rollen**
  - Verdeel het deeg in 8 gelijke ballen.  
  - Rol elke bal uit tot een ovale plak van ca. 20 cm lang.  
- **Bakken**
  - Verhit een ingevette koekenpan of skillet op middelhoog vuur.  
  - Bak elke naan ca. 1 minuut per kant, tot ze goudbruin zijn en bubbelen.  
- **Afwerking**
  - Meng de knoflook met de gesmolten boter.  
  - Bestrijk de warme naan met het knoflook-botermengsel.  
  - Bestrooi met wat zout en garneer met koriander of peterselie.  

### **Serveren**
- Serveer warm bij curry’s, stoofgerechten of als snack met dips.  
- Eventueel extra besprenkelen met olijfolie of chilivlokken.
Nu volgt de lijst van recepten. Verwerk alle recepten die hierachter komen:
```
