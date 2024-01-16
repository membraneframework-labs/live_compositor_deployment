# AWS EC2 Deployment Example

This configuration is an example of how to deploy a Live Compositor instance to AWS EC2. It comes in 2 variants:
- Standalone server
- Example membrane project

## Example variants

### Standalone server

The standalone server configuration variant will just deploy an instance with an initialized compositor. This is a good production use case, but given that compositor communicates over RTP there is not much you can do with it without adding some services that send or consume RTP. For a more interactive example check out the example Membrane project below.

### Example Membrane project

This example is using `membrane-video-compositor-plugin` to create and interact with a Live Compositor instance. An example pipeline listens for RTMP streams, sends it to the compositor, and publishes the output as an HLS endpoint.

After deploying this example you can:
- Send RTMP stream to the 9000 port e.g.
  ```bash
  ffmpeg -re -f lavfi -i testsrc -vf scale=1280:720 \
    -vcodec libx264 -profile:v baseline -preset ultrafast -pix_fmt yuv420p \
    -f flv rtmp://PUBLIC_INSTANCE_IP:9000/app/stream_key
  ```
- Access the resulting HLS stream using:
  - `ffplay` command included with FFmpeg
    ```
    ffplay http://PUBLIC_INSTANCE_IP:9001/index.m3u8
    ```
  - `vlc` player
    ```
    vlc http://PUBLIC_INSTANCE_IP:9001/index.m3u8
    ```

> You can open the stream using a browser if you go to [hlsjs.video-dev.org/demo/](https://hlsjs.video-dev.org/demo/) and change the demo URL to `"http://PUBLIC_INSTANCE_IP:9001/index.m3u8"`. However, in most cases browser will block you from opening that stream because of a requirement to use HTTPS or CORS configuration, so using this method might require you to figure out those issues on your side.

## Deployment

To deploy this configuration you need to build a new AMI image using `packer`, update terraform configuration, and apply it. This guide can be deployed on regular CPU-only instances, but for optimal performance, you should consider using GPU instances.

### Requirements

- Update **main.tf** and **packer/\*.pkr.hcl\*** files to use correct region.
- Install `terraform` and `packer`. If you are using `nix` package manager there is already `flake.nix` with all the necessary dependencies configured there.
- To use GPU instances you need to have appropriate quotas configured in your AWS account in the region you want to deploy it.

### Build AMI (Amazon Machine Image)

In general, AMIs do not have to be built on the same instance they will run on, but for GPU support appropriate drivers have to be installed so separate AMIs for GPU and non-GPU instances might be needed. To build below image variants with GPU support add `-var 'with-gpu=true'` to the packer command e.g. `packer build -var 'with-gpu=true' TEMPLATE_PATH.pkr.hcl`.

To build the standalone variant:
- Go to the `./packer` directory.
- Run `packer build standalone.pkr.hcl`.

To build the example Membrane project:
- Go to the **project** directory.
- Build the project with `MIX_ENV=prod mix release`.
- Go to the **aws-ec2-terraform/packer** directory.
- Run `packer build membrane.pkr.hcl`.

At the end of each build process, an ID of the newly created AMI will be printed.

### Deploy terraform config

- Update `ami` field in `aws_instance.demo_instance` in **main.tf** with the value from the previous step.
- Depending on how you built your AMI, run either
  - `terraform apply -var="with-gpu=true"` in **aws-ec2-terraform** directory to deploy image on GPU instance.
  - `terraform apply` in **aws-ec2-terraform** directory to deploy image on CPU-only instance.
