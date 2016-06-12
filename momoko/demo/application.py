import momoko
import tornado
import tornado.web

PORT = 8888

class MainHandler(tornado.web.RequestHandler):

    def get(self):
        self.write("Hello, world")


class SleepHandler(tornado.web.RequestHandler):

    @tornado.gen.coroutine
    def get(self, sleep_ms):
        # Ask the database to sleep
        cursor = yield self.application.db.execute("SELECT random(), pg_sleep(%(sleep_seconds)s)", {"sleep_seconds": int(sleep_ms) / 1000.0})
        result = cursor.fetchone()
        print("Result: {}\nSlept {} ms".format(result[0], sleep_ms))


def make_app(ioloop, pool_size=20):
    application = tornado.web.Application([
        (r"/", MainHandler),
        (r"/sleep/(\d+)", SleepHandler),
    ])
    application.db = momoko.Pool(
        dsn='dbname=pmd user=pmd password=password host=localhost port=5432',
        size=pool_size,
        ioloop=ioloop
    )
    return application

if __name__ == "__main__":
    io_loop = tornado.ioloop.IOLoop.current()
    app = make_app(io_loop)
    print("Listening on port {}".format(PORT))
    app.listen(PORT)
    print("Connecting to database...")
    io_loop.add_future(app.db.connect(), lambda x: None)
    io_loop.start()
