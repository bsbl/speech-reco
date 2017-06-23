from flask import Flask, render_template
from flask_wtf import FlaskForm
from wtforms import StringField, SubmitField, HiddenField, TextAreaField
from wtforms.validators import DataRequired
from operator import itemgetter
import json
import redis
import sys
import time
import requests



app = Flask('__name__')
app.config.from_object('config')

rcache = redis.StrictRedis(host='localhost', port=6379, db=1)

class SearchForm(FlaskForm):
  search = StringField('search', validators=[DataRequired()])

class UpdateForm(FlaskForm):
  titleupdate = HiddenField('titleupdate')
  textupdate = HiddenField('textupdate')
  user = HiddenField('user', validators=[DataRequired()])
  record_id = HiddenField('record_id', validators=[DataRequired()])
  save = SubmitField(label='Save')
  delete = SubmitField(label='Delete')
  done = SubmitField(label='Mark as Done')



@app.route('/')
def index():
  return render_template('index.html')

@app.route('/records', methods=['GET','POST'])
def records():
  search = ''
  cur_record_id = None
  cur_user = None
  form = SearchForm()
  updateform = UpdateForm()
  if form.validate_on_submit():
    search = form.search.data
  if updateform.validate_on_submit():
    record_id = updateform.record_id.data
    user = updateform.user.data
    if updateform.save.data:
      print("save", file=sys.stderr)
      text = updateform.textupdate.data
      title = updateform.titleupdate.data
      up = {}
      up['text'] = text
      up['title'] = title
      up['status'] = 'Modified'
      headers = {'content-type': 'application/json'}
      r = requests.post('http://localhost:5000/update/' + user + '/' + record_id , headers=headers, data=json.dumps(up))
      if r.status_code == 200:
        cur_record_id = record_id
        cur_user = user
    elif updateform.done.data:
      print("done", file=sys.stderr)
      text = updateform.textupdate.data
      title = updateform.titleupdate.data
      up = {}
      up['text'] = text
      up['title'] = title
      up['status'] = 'Done'
      headers = {'content-type': 'application/json'}
      r = requests.post('http://localhost:5000/update/' + user + '/' + record_id , headers=headers, data=json.dumps(up))
      if r.status_code == 200:
        cur_record_id = record_id
        cur_user = user
    elif updateform.delete.data:
      print("delete", file=sys.stderr)
      r = requests.get('http://localhost:5000/delete/' + user + '/' + record_id)
      if r.status_code == 200:
        cur_record_id = None
        cur_user = None

  records = {} 
  for user in rcache.keys('user:*' + search + '*'):
    user_records = json.loads(rcache.get(user).decode('utf-8'))['records']
    for record_id in user_records.keys():
      record = user_records[record_id]
      record['user'] = user.decode('utf-8').split(':')[1]
      record_time = time.localtime(record['timestamp'])
      record_time_r = time.strftime("%a, %d %b %Y %H:%M:%S", record_time)
      record['time'] = record_time_r
      records[record_id] = record
#  sorted_records = sorted(records, key=itemgetter('record_id'), reverse=True)
  return render_template('records.html', records=records, form=form, updateform=updateform, cur_record_id=cur_record_id, cur_user=cur_user)
