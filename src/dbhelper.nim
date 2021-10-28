import norm/[model, sqlite]

proc create*[T: Model](dbConn: DbConn, model: T): T
  {.raises: [DbError, ValueError].} =
  ## Inserts the model with the properties and returns it with the newly
  ## inserted ID
  var m = model
  dbConn.insert m
  let id = dbConn.count(T)
  m.id = id
  result = m
