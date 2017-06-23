from flask import Flask, request, Response
from flask_restful import Resource, Api
import json
import redis
import sys
import time


app = Flask(__name__)
api = Api(app)

rcache = redis.StrictRedis(host='localhost', port=6379, db=1)

class records(Resource):
  def post(self,user):
    data = request.get_json()
    data['timestamp'] = time.time()
    data['status'] = 'New'
    record_id=rcache.incr('record:id')
    print("post data: %s" % json.dumps(data), file=sys.stderr)
    if rcache.exists('user:' + user):
      userdata = json.loads(rcache.get('user:' + user).decode('utf-8'))
    else:
      userdata = {}
    if 'records' not in userdata:
      userdata['records'] = {}

    userdata['records'][record_id] = data

    rcache.set('user:' + user, json.dumps(userdata))
    result = {}
    result['status'] = "success"
    result['message'] = "record stored"

    return result

  def get(self,user):
    if rcache.exists(user):
      userdata = json.loads(rcache.get(user).decode('utf-8'))
    else:
      userdata = {}
    return userdata;

class update_record(Resource):
  def post(self,user,record_id):
    data = request.get_json()
    userdata = json.loads(rcache.get('user:' + user).decode('utf-8'))
    record = userdata['records'][record_id]  
    record['text'] = data['text']
    record['title'] = data['title']
    record['status'] = data['status']
    userdata['records'][record_id] = record
    rcache.set('user:' + user, json.dumps(userdata))
    result = {}
    result['status'] = "success"
    result['message'] = "record updated"
    return result

class delete_record(Resource):
  def get(self,user,record_id):
    data = request.get_json()
    userdata = json.loads(rcache.get('user:' + user).decode('utf-8'))
    del userdata['records'][record_id]
    rcache.set('user:' + user, json.dumps(userdata))
    result = {}
    result['status'] = "success"
    result['message'] = "record deleted"
    return result


api.add_resource(records, '/records/<string:user>')
api.add_resource(update_record, '/update/<string:user>/<string:record_id>')
api.add_resource(delete_record, '/delete/<string:user>/<string:record_id>')

