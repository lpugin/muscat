pl = [
"Aachen",
"Aarau",
"Baden",
"Basel",
"Bath",
"Berlin",
"Bern",
"Binningen",
"Bologna",
"Brugg",
"Budapest",
"Burgdorf",
"Chur",
"Crema",
"Darmstadt",
"Dessau",
"Dornach",
"Dresden",
"Einsiedeln",
"Essen",
"Estavayer-le-Lac",
"Exeter, New Hampshire",
"Fontainebleau",
"Genève",
"Grätz [jetzt: Hradec nad Moravicí]",
"Hamburg",
"Heidelberg",
"Huttwil",
"Jauernig [jetzt: Javorník]",
"Köln",
"København",
"Langnau im Emmental",
"Lausanne",
"Leipzig",
"Lenzburg",
"London",
"Luzern",
"Milano",
"München",
"Napoli",
"Neuchâtel",
"Neustädterkirchhof Berlin",
"Nieder-Erlinsbach",
"Nyon",
"Oels [jetzt: Oleśnica]",
"Olten",
"Paris",
"Parma",
"Pfarrkirche St. Leodegar im Hof, Luzern",
"Pillnitz bei Dresden",
"Praha",
"Reggio Emilia",
"Reinach",
"Roma",
"Sachseln",
"Sarnen",
"Schaffhausen",
"Schlosshof an der March",
"Schwyz",
"Solothurn",
"St. Gallen",
"Stans",
"Stuttgart",
"Torino",
"Venezia",
"Versailles",
"Weimar",
"Wien",
"Winterthur",
"Yverdon-les-Bains",
"Zürich"]


#pl.each do |p|
#    place = Place.find_by_name(p)
#    puts "#{place.id}\t#{p}"
#end

CSV.foreach("pip.tsv", col_sep: "\t") do |r|
    place = Place.find_by_name(r[1])
    next if !place
    puts "#{place.id}\t#{r[1]}\t#{r[0]}\t#{r[1]}"
end
