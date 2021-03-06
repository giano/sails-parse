// Generated by CoffeeScript 1.6.3
var adapter, async, classify, models, parse_connection, parse_link, titleize;

async = require("async");

models = {};

parse_connection = null;

titleize = function(str) {
  if (str == null) {
    return '';
  }
  str = String(str).toLowerCase();
  return str.replace(/(?:^|\s|-)\S/g, function(c) {
    return c.toUpperCase();
  });
};

classify = function(str) {
  return titleize(String(str).replace(/[\W_]/g, ' ')).replace(/\s/g, '');
};

parse_link = function() {
  if (parse_connection != null) {
    return parse_connection;
  }
  parse_connection = require("./lib/parse.js").Parse;
  parse_connection.initialize(adapter.config.application_id, adapter.config.javascript_key, adapter.config.master_key);
  return parse_connection;
};

adapter = module.exports = {
  syncable: false,
  defaults: {
    migrate: "alter"
  },
  registerCollection: function(collection, cb) {
    parse_link();
    return adapter.define(collection.identity, collection.definition, cb);
  },
  teardown: function(cb) {
    return cb();
  },
  define: function(collectionName, definition, cb) {
    var cl_name, out_model;
    cl_name = collectionName;
    out_model = parse_link().Object.extend(cl_name);
    out_model._schema = definition;
    models[collectionName.toLowerCase()] = out_model;
    return cb();
  },
  describe: function(collectionName, cb) {
    var attributes;
    attributes = {};
    return cb(null, attributes);
  },
  drop: function(collectionName, cb) {
    delete models[collectionName.toLowerCase()];
    return cb();
  },
  create: function(collectionName, values, cb) {
    var new_model;
    if (models[collectionName.toLowerCase()] == null) {
      return cb("Model not found", null);
    }
    new_model = new models[collectionName.toLowerCase()]();
    return new_model.save(values, {
      success: function(out_elem) {
        return cb(null, out_elem);
      },
      error: function(out_elem, error) {
        return cb(error, out_elem);
      }
    });
  },
  find: function(collectionName, options, cb) {
    var k, query, v, _ref, _ref1, _ref2;
    if (models[collectionName.toLowerCase()] == null) {
      return cb("Model not found", null);
    }
    query = new (parse_link().Query)(models[collectionName.toLowerCase()]);
    if (((options != null ? (_ref = options.where) != null ? _ref.id : void 0 : void 0) != null)) {
      return query.get(options.where.id, {
        success: function(out_elem) {
          return cb(null, [out_elem]);
        },
        error: function(out_elem, error) {
          return cb(error, null);
        }
      });
    } else if (((options != null ? options.where : void 0) != null)) {
      if (options != null ? options.limit : void 0) {
        query.limit(options != null ? options.limit : void 0);
      }
      if (options != null ? options.skip : void 0) {
        query.skip(options != null ? options.skip : void 0);
      }
      if (options != null ? options.order : void 0) {
        _ref1 = options != null ? options.order : void 0;
        for (k in _ref1) {
          v = _ref1[k];
          if (v.toLowerCase() === "asc") {
            query.ascending(k);
          } else {
            query.descending(k);
          }
        }
      }
      _ref2 = options != null ? options.where : void 0;
      for (k in _ref2) {
        v = _ref2[k];
        if (_.isObject(v) && ((v != null ? v.comparer : void 0) != null)) {
          query[v != null ? v.comparer : void 0](k, v.value);
        } else {
          query.equalTo(k, v);
        }
      }
      return query.find({
        success: function(out_elems) {
          return cb(null, out_elems);
        },
        error: function(out_elems, error) {
          return cb(error, null);
        }
      });
    } else {
      return adapter.find(collectionName, {
        where: options
      }, cb);
    }
  },
  "native": function(collectionName, cb) {
    if (models[collectionName.toLowerCase()] == null) {
      return cb("Model not found", null);
    }
    return cb(null, models[collectionName.toLowerCase()]);
  },
  count: function(collectionName, options, cb) {
    var k, query, v, _ref;
    if (models[collectionName.toLowerCase()] == null) {
      return cb("Model not found", null);
    }
    query = new (parse_link().Query)(models[collectionName.toLowerCase()]);
    if (((options != null ? options.where : void 0) != null)) {
      _ref = options != null ? options.where : void 0;
      for (k in _ref) {
        v = _ref[k];
        if (_.isObject(v) && ((v != null ? v.comparer : void 0) != null)) {
          query[v != null ? v.comparer : void 0](k, v.value);
        } else {
          query.equalTo(k, v);
        }
      }
      return query.count({
        success: function(out_elems_count) {
          return cb(null, out_elems_count);
        },
        error: function(out_elems, error) {
          return cb(error, null);
        }
      });
    } else {
      return adapter.count(collectionName, {
        where: options
      }, cb);
    }
  },
  update: function(collectionName, options, values, cb) {
    return adapter.find(collectionName, options, function(error, items) {
      if (error != null) {
        return cb(error, null);
      }
      return async.forEach(items, function(item, elem_cb) {
        var k, v;
        for (k in values) {
          v = values[k];
          item.set(k, v);
        }
        return item.save(elem_cb);
      }, function(error) {
        if (error != null) {
          return cb(error, null);
        }
        return cb(null, items);
      });
    });
  },
  destroy: function(collectionName, options, cb) {
    adapter.find(collectionName, options, function(error, items) {
      if (error != null) {
        return cb(error, null);
      }
      return async.forEach(items, function(item, elem_cb) {
        return item.destroy(elem_cb);
      }, function(error) {
        if (error != null) {
          return cb(error, null);
        }
        return cb(null, items);
      });
    });
    return cb();
  },
  stream: function(collectionName, options, stream) {}
};
