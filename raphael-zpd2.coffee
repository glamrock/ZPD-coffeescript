raphaelZPDId = 0
RaphaelZPD = (raphaelPaper, o) ->
  supportsSVG = ->
    document.implementation.hasFeature "http://www.w3.org/TR/SVG11/feature#BasicStructure", "1.1"
  return null  unless supportsSVG()
  me = this
  me.initialized = false
  me.opts = 
    zoom: true
    pan: true
    drag: true
    zoomThreshold: null
  
  me.id = ++raphaelZPDId
  me.root = raphaelPaper.canvas
  me.gelem = document.createElementNS("http://www.w3.org/2000/svg", "g")
  me.gelem.id = "viewport" + me.id
  me.root.appendChild me.gelem

RaphaelZPD = (raphaelPaper, o) ->
  supportsSVG = ->
    document.implementation.hasFeature "http://www.w3.org/TR/SVG11/feature#BasicStructure", "1.1"
  overrideElements = (paper) ->
    elementTypes = [ "circle", "rect", "ellipse", "image", "text", "path" ]
    i = 0
    
    while i < elementTypes.length
      overrideElementFunc paper, elementTypes[i]
      i++
  overrideElementFunc = (paper, elementType) ->
    paper[elementType] = (oldFunc) ->
      ->
        element = oldFunc.apply(paper, arguments)
        element.gelem = me.gelem
        me.gelem.appendChild element.node
        element
    (paper[elementType])
  transformEvent = (evt) ->
    return evt  unless typeof evt.clientX == "number"
    svgDoc = evt.target.ownerDocument
    g = svgDoc.getElementById("viewport" + me.id)
    p = me.getEventPoint(evt)
    p = p.matrixTransform(g.getCTM().inverse())
    evt.zoomedX = p.x
    evt.zoomedY = p.y
    evt
  return null  unless supportsSVG()
  me = this
  me.initialized = false
  me.opts = 
    zoom: true
    pan: true
    drag: true
    zoomThreshold: null
  
  me.id = ++raphaelZPDId
  me.root = raphaelPaper.canvas
  me.gelem = document.createElementNS("http://www.w3.org/2000/svg", "g")
  me.gelem.id = "viewport" + me.id
  me.root.appendChild me.gelem
  overrideElements raphaelPaper
  events = [ "click", "dblclick", "mousedown", "mousemove", "mouseout", "mouseover", "mouseup", "touchstart", "touchmove", "touchend", "orientationchange", "touchcancel", "gesturestart", "gesturechange", "gestureend" ]
  events.forEach (eventName) ->
    oldFunc = Raphael.el[eventName]
    Raphael.el[eventName] = (fn, scope) ->
      return  if fn == undefined
      wrap = (evt) ->
        fn.apply this, [ transformEvent(evt) ]
      
      oldFunc.apply this, [ wrap, scope ]
  
  me.state = "none"
  me.stateTarget = null
  me.stateOrigin = null
  me.stateTf = null
  me.zoomCurrent = 0
  if o
    for key of o
      me.opts[key] = o[key]  if me.opts[key] != undefined
  me.setupHandlers = (root) ->
    me.root.onmousedown = me.handleMouseDown
    me.root.onmousemove = me.handleMouseMove
    me.root.onmouseup = me.handleMouseUp
    if navigator.userAgent.toLowerCase().indexOf("webkit") >= 0
      me.root.addEventListener "mousewheel", me.handleMouseWheel, false
    else
      me.root.addEventListener "DOMMouseScroll", me.handleMouseWheel, false
  
  me.getEventPoint = (evt) ->
    p = me.root.createSVGPoint()
    p.x = evt.clientX
    p.y = evt.clientY
    p
  
  me.setCTM = (element, matrix) ->
    s = "matrix(" + matrix.a + "," + matrix.b + "," + matrix.c + "," + matrix.d + "," + matrix.e + "," + matrix.f + ")"
    element.setAttribute "transform", s
  
  me.dumpMatrix = (matrix) ->
    s = "[ " + matrix.a + ", " + matrix.c + ", " + matrix.e + "\n  " + matrix.b + ", " + matrix.d + ", " + matrix.f + "\n  0, 0, 1 ]"
    s
  
  me.setAttributes = (element, attributes) ->
    for i of attributes
      element.setAttributeNS null, i, attributes[i]
  
  me.handleMouseWheel = (evt) ->
    return  unless me.opts.zoom
    evt.preventDefault()  if evt.preventDefault
    evt.returnValue = false
    svgDoc = evt.target.ownerDocument
    
    if evt.wheelDelta
      delta = evt.wheelDelta / 3600
    else
      delta = evt.detail / -90
    if delta > 0
      return  if me.opts.zoomThreshold[1] <= me.zoomCurrent  if me.opts.zoomThreshold
      me.zoomCurrent++
    else
      return  if me.opts.zoomThreshold[0] >= me.zoomCurrent  if me.opts.zoomThreshold
      me.zoomCurrent--
    z = 1 + delta
    g = svgDoc.getElementById("viewport" + me.id)
    p = me.getEventPoint(evt)
    p = p.matrixTransform(g.getCTM().inverse())
    k = me.root.createSVGMatrix().translate(p.x, p.y).scale(z).translate(-p.x, -p.y)
    me.setCTM g, g.getCTM().multiply(k)
    me.stateTf = g.getCTM().inverse()  unless me.stateTf
    me.stateTf = me.stateTf.multiply(k.inverse())
  
  me.handleMouseMove = (evt) ->
    evt.preventDefault()  if evt.preventDefault
    evt.returnValue = false
    svgDoc = evt.target.ownerDocument
    g = svgDoc.getElementById("viewport" + me.id)
    if me.state == "pan"
      return  unless me.opts.pan
      p = me.getEventPoint(evt).matrixTransform(me.stateTf)
      me.setCTM g, me.stateTf.inverse().translate(p.x - me.stateOrigin.x, p.y - me.stateOrigin.y)
    else if me.state == "move"
      return  unless me.opts.drag
      p = me.getEventPoint(evt).matrixTransform(g.getCTM().inverse())
      me.setCTM me.stateTarget, me.root.createSVGMatrix().translate(p.x - me.stateOrigin.x, p.y - me.stateOrigin.y).multiply(g.getCTM().inverse()).multiply(me.stateTarget.getCTM())
      me.stateOrigin = p
  
  me.handleMouseDown = (evt) ->
    evt.preventDefault()  if evt.preventDefault
    evt.returnValue = false
    svgDoc = evt.target.ownerDocument
    g = svgDoc.getElementById("viewport" + me.id)
    if evt.target.tagName == "svg" or not me.opts.drag
      return  unless me.opts.pan
      me.state = "pan"
      me.stateTf = g.getCTM().inverse()
      me.stateOrigin = me.getEventPoint(evt).matrixTransform(me.stateTf)
    else
      return  if not me.opts.drag or evt.target.draggable == false
      me.state = "move"
      me.stateTarget = evt.target
      me.stateTf = g.getCTM().inverse()
      me.stateOrigin = me.getEventPoint(evt).matrixTransform(me.stateTf)
  
  me.handleMouseUp = (evt) ->
    evt.preventDefault()  if evt.preventDefault
    evt.returnValue = false
    svgDoc = evt.target.ownerDocument
    me.state = ""  if (me.state == "pan" and me.opts.pan) or (me.state == "move" and me.opts.drag)
  
  me.setupHandlers me.root
  me.initialized = true

Raphael.fn.ZPDPanTo = (x, y) ->
  me = this
  unless me.gelem.getCTM()?
    alert "failed"
    return null
  stateTf = me.gelem.getCTM().inverse()
  svg = document.getElementsByTagName("svg")[0]
  alert "no svg"  unless svg.createSVGPoint
  p = svg.createSVGPoint()
  p.x = x
  p.y = y
  p = p.matrixTransform(stateTf)
  element = me.gelem
  matrix = stateTf.inverse().translate(p.x, p.y)
  s = "matrix(" + matrix.a + "," + matrix.b + "," + matrix.c + "," + matrix.d + "," + matrix.e + "," + matrix.f + ")"
  element.setAttribute "transform", s
  me