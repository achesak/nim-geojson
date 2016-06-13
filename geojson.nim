# Nim module for parsing GeoJSON data.

# Written by Adam Chesak.
# Released under the MIT open source license.


import json
import strutils


type
    FeatureCollection* = ref FeatureCollectionInternal
    FeatureCollectionInternal* = object
        featureType* : string
        points* : seq[Point]
        multiPoints* : seq[MultiPoint]
        lineStrings* : seq[LineString]
        multiLineStrings* : seq[MultiLineString]
        polygons* : seq[Polygon]
        multiPolygons* : seq[MultiPolygon]
        geometryCollections* : seq[GeometryCollection]
        totalFeatures* : int
    
    Feature* = ref object of RootObj
        featureType* : string
        index* : int
        properties* : seq[tuple[key: string, val: string]]
    
    Point* = ref object of Feature
        coordinates* : seq[float]
    
    MultiPoint* = ref object of Feature
        coordinates* : seq[seq[float]]
    
    LineString* = ref object of Feature
        coordinates* : seq[seq[float]] # Additional restrictions, but let parsing handle that.
    
    MultiLineString* = ref object of Feature
        coordinates* : seq[seq[seq[float]]]
    
    Polygon* = ref object of Feature
        coordinates* : seq[seq[seq[float]]]
    
    MultiPolygon* = ref object of Feature
        coordinates* : seq[seq[seq[seq[float]]]] # This is getting ridiculous.
    
    GeometryCollection* = ref object of Feature
        geometries* : seq[Feature]
        points* : seq[Point]
        multiPoints* : seq[MultiPoint]
        lineStrings* : seq[LineString]
        multiLineStrings* : seq[MultiLineString]
        polygons* : seq[Polygon]
        multiPolygons* : seq[MultiPolygon]
        geometryCollections* : seq[GeometryCollection]
    
    GeoJSONError* = object of Exception



proc parseProperties(f : JsonNode): seq[tuple[key: string, val: string]] = 
    ## Internal proc. Parses feature properties.
    
    var props = newSeq[tuple[key: string, val: string]]()
    
    if f.hasKey("properties"):
        for key, val in pairs(f["properties"]):
            props.add((key, val.getStr()))
    
    return props


proc parsePoint(f : JsonNode, i : int): Point = 
    ## Internal proc. Parses a Point.
    
    var p : Point = Point(featureType: "Point", properties: parseProperties(f), index: i)
    
    var c : seq[float] = @[]
    for i in f["geometry"]["coordinates"]:
        c.add(i.getFNum())
    p.coordinates = c
    
    return p


proc parseMultiPoint(f : JsonNode, i : int): MultiPoint = 
    ## Internal proc. Parses a MultiPoint.
    
    var p : MultiPoint = MultiPoint(featureType: "MultiPoint", properties: parseProperties(f), index : i)
    
    var c : seq[seq[float]] = @[]
    for i in f["geometry"]["coordinates"]:
        var v : seq[float] = @[]
        for j in i:
            v.add(j.getFNum())
        c.add(v)
    p.coordinates = c
    
    return p


proc parseLineString(f : JsonNode, i : int): LineString = 
    ## Internal proc. Parses a LineString.
    
    var p : LineString = LineString(featureType: "LineString", properties: parseProperties(f), index: i)
    
    var c : seq[seq[float]] = @[]
    for i in f["geometry"]["coordinates"]:
        var v : seq[float] = @[]
        for j in i:
            v.add(j.getFNum())
        c.add(v)
    p.coordinates = c
    
    if len(c) < 2:
        raise newException(GeoJSONError, "parseLineString(): LineString must contain at least two coordinate pairs, " & intToStr(len(c)) & " given")
    
    return p


proc parseMultiLineString(f : JsonNode, i : int): MultiLineString = 
    ## Internal proc. Parses a MultiLineString.
    
    var p : MultiLineString = MultiLineString(featureType: "MultiLineString", properties: parseProperties(f), index: i)
    
    var c : seq[seq[seq[float]]] = @[]
    for i in f["geometry"]["coordinates"]:
        var v : seq[seq[float]] = @[]
        for j in i:
            var b : seq[float] = @[]
            for k in j:
                b.add(k.getFNum())
            v.add(b)
        
        if len(v) < 2:
            raise newException(GeoJSONError, "parseLineString(): MultiLineString element must contain at least two coordinate pairs, " & intToStr(len(v)) & " given")
        
        c.add(v)
    p.coordinates = c
    
    return p


proc parsePolygon(f : JsonNode, i : int): Polygon = 
    ## Internal proc. Parses a Polygon.
    
    var p : Polygon = Polygon(featureType: "Polygon", properties: parseProperties(f), index: i)
    
    var c : seq[seq[seq[float]]] = @[]
    for i in f["geometry"]["coordinates"]:
        var v : seq[seq[float]] = @[]
        for j in i:
            var b : seq[float] = @[]
            for k in j:
                b.add(k.getFNum())
            v.add(b)
        c.add(v)
    p.coordinates = c
    
    return p


proc parseMultiPolygon(f : JsonNode, i : int): MultiPolygon = 
    ## Internal proc. Parses a MultiPolygon.
    
    var p : MultiPolygon = MultiPolygon(featureType: "MultiPolygon", properties: parseProperties(f), index: i)
    
    # Perhaps I should find time to rewrite this to not be so shit.
    var c : seq[seq[seq[seq[float]]]] = @[]
    for i in f["geometry"]["coordinates"]:
        var v : seq[seq[seq[float]]] = @[]
        for j in i:
            var b : seq[seq[float]] = @[]
            for k in j:
                var n : seq[float] = @[]
                for l in k:
                    n.add(l.getFNum())
                b.add(n)
            v.add(b)
        c.add(v)
    p.coordinates = c
    
    return p


proc parseGeometryCollection(f : JsonNode, i : int): GeometryCollection = 
    ## Internal proc. Parses a GeometryCollection.
    
    var p : GeometryCollection = GeometryCollection(featureType: "GeometryCollection", properties: parseProperties(f), index: i)
    
    var f1 : seq[Point] = @[]
    var f2 : seq[MultiPoint] = @[]
    var f3 : seq[LineString] = @[]
    var f4 : seq[MultiLineString] = @[]
    var f5 : seq[Polygon] = @[]
    var f6 : seq[MultiPolygon] = @[]
    var f7 : seq[GeometryCollection] = @[]
    for i in 0..len(f["geometries"])-1:
        var t : string = f["geometries"][i]["type"].getStr()
        var e : JsonNode = f["geometries"][i]
        if t == "Point":
            f1.add(parsePoint(e, i))
        elif t == "MultiPoint":
            f2.add(parseMultiPoint(e, i))
        elif t == "LineString":
            f3.add(parseLineString(e, i))
        elif t == "MultiLineString":
            f4.add(parseMultiLineString(e, i))
        elif t == "Polygon":
            f5.add(parsePolygon(e, i))
        elif t == "MultiPolygon":
            f6.add(parseMultiPolygon(e, i))
        elif t == "GeometryCollection":
            f7.add(parseGeometryCollection(e, i))
        else:
            raise newException(GeoJSONError, "parseGeometryCollection(): unrecognized feature type \"" & t & "\"")
    p.points = f1
    p.multiPoints = f2
    p.lineStrings = f3
    p.multiLineStrings = f4
    p.polygons = f5
    p.multiPolygons = f6
    p.geometryCollections = f7
    
    return p


proc parseGeoJSON*(data : string): FeatureCollection = 
    ## Parses GeoJSON data from ``data``.
    
    var f : JsonNode = parseJson(data)
    var p : FeatureCollection = FeatureCollection(featureType: "FeatureCollection")
    
    var f1 : seq[Point] = @[]
    var f2 : seq[MultiPoint] = @[]
    var f3 : seq[LineString] = @[]
    var f4 : seq[MultiLineString] = @[]
    var f5 : seq[Polygon] = @[]
    var f6 : seq[MultiPolygon] = @[]
    var f7 : seq[GeometryCollection] = @[]
    for i in 0..len(f["features"])-1:
        var t : string = f["features"][i]["geometry"]["type"].getStr()
        var e : JsonNode = f["features"][i]
        if t == "Point":
            f1.add(parsePoint(e, i))
        elif t == "MultiPoint":
            f2.add(parseMultiPoint(e, i))
        elif t == "LineString":
            f3.add(parseLineString(e, i))
        elif t == "MultiLineString":
            f4.add(parseMultiLineString(e, i))
        elif t == "Polygon":
            f5.add(parsePolygon(e, i))
        elif t == "MultiPolygon":
            f6.add(parseMultiPolygon(e, i))
        elif t == "GeometryCollection":
            f7.add(parseGeometryCollection(e, i))
        else:
            raise newException(GeoJSONError, "parseGeoJSON(): unrecognized feature type \"" & t & "\"")
    p.points = f1
    p.multiPoints = f2
    p.lineStrings = f3
    p.multiLineStrings = f4
    p.polygons = f5
    p.multiPolygons = f6
    p.geometryCollections = f7
    p.totalFeatures = len(f1) + len(f2) + len(f3) + len(f4) + len(f5) + len(f6) + len(f7)
    
    return p


proc parseGeoJSON*(data : File): FeatureCollection = 
    ## Reads data from specified file and parses as GeoJSON.
    
    return parseGeoJSON(readAll(data))


proc parseGeoJSONFile*(filename : string): FeatureCollection = 
    ## Reads data from specified file and parses as GeoJSON.
    
    return parseGeoJSON(readFile(filename))
